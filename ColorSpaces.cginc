// Modified from https://www.chilliant.com/rgb2hsv.html
// Defines conversions between a few colour spaces:
// * RGB: You know this one. (Actually sRGB.)
// * HUE: Just hue and somewhat cheap to work with.
// * HCY: Supposed to be better than HSV/HSL. Expensive.
// * HSV: V: How much white light is shined on.
// * HSL: L: How much white paint is mixed in.
// * HCL: Supposedly more uniform hue, but eh. (THe 2005-paper HCL.)
//        Very expensive. hcl(*,1,1) is about as bright as hsv(*,1,1).
//        The (x,1,y) slices look really bad compared to hsv.
// * NSV: For-me-visually-normalised hue, otherwise
//        the same as hsv. Not a real colour space.
//        Manually graphed what I liked, then turned
//        it into magic numbers, so it's very subjective.
//        It's a n instead of a h because it's a very
//        shitty knockoff.
// * GRAY: Speaks for itself. For obvious reasons, one-way.

#ifndef COLOR_SPACE_CONVERTERS
#define COLOR_SPACE_CONVERTERS

#ifndef PI
#define PI 3.1415926536
#endif
#define __color_space_converters_Epsilon 1e-10

float3 rgb2gray(float3 col) {
    // Convert from sRGB to linear RGB
    col = (col <= 0.04045) * col/12.92
        + (col >  0.04045) * pow((col + 0.055)/1.055, 2.4);
    // Gray the scale
    col = dot(col, float3(0.213, 0.715, 0.072));
    // Convert from linear RGB to sRGB
    return (col <= 0.0031308) * col*12.92
         + (col >  0.0031308) * (1.055*pow(col, 1/2.4) - 0.055);
}
float3 rgb2grey(float3 col) {
    return rgb2gray(col);
}

float3 rgb2hcv(float3 RGB) {
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + __color_space_converters_Epsilon) + Q.z);
    return float3(H, C, Q.x);
}

// ====== HSV <=> RGB ======
// Converts HSV (h,1,1) to RGB.
float3 hue2rgb(float H) {
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float rgb2hue(float3 RGB) {
    return rgb2hcv(RGB).x;
}

float3 rgb2hsv(float3 RGB) {
    float3 HCV = rgb2hcv(RGB);
    float S = HCV.y / (HCV.z + __color_space_converters_Epsilon);
    return float3(HCV.x, S, HCV.z);
}

float3 hsv2rgb(float3 HSV) {
    float3 RGB = hue2rgb(HSV.x);
    return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

// ====== HSL <=> RGB ======

float3 rgb2hsl(float3 RGB) {
    float3 HCV = rgb2hcv(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + __color_space_converters_Epsilon);
    return float3(HCV.x, S, L);
}

float3 hsl2rgb(float3 HSL) {
    float3 RGB = hue2rgb(HSL.x);
    float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
    return (RGB - 0.5) * C + HSL.z;
}

// ====== HCY <=> RGB ======

// The weights of RGB contributions to luminance.
// Should sum to unity.
#define __color_space_converters_HCYwts float3(0.299, 0.587, 0.114)
 
float3 hcy2rgb(float3 HCY) {
    float3 RGB = hue2rgb(HCY.x);
    float Z = dot(RGB, __color_space_converters_HCYwts);
    if (HCY.z < Z) {
        HCY.y *= HCY.z / Z;
    } else if (Z < 1) {
        HCY.y *= (1 - HCY.z) / (1 - Z);
    }
    return (RGB - Z) * HCY.y + HCY.z;
}

float3 rgb2hcy(float3 RGB) {
    // Corrected by David Schaeffer
    float3 HCV = rgb2hcv(RGB);
    float Y = dot(RGB, __color_space_converters_HCYwts);
    float Z = dot(hue2rgb(HCV.x), __color_space_converters_HCYwts);
    if (Y < Z) {
      HCV.y *= Z / (__color_space_converters_Epsilon + Y);
    } else {
      HCV.y *= (1 - Z) / (__color_space_converters_Epsilon + 1 - Y);
    }
    return float3(HCV.x, HCV.y, Y);
}

// ===== HCL <=> RGB ======

#define __color_space_converters_HCLgamma 3
#define __color_space_converters_HCLy0 100
// HCLmaxL = exp(HCLgamma / HCLy0) - 0.5
#define __color_space_converters_HCLmaxL 0.530454533953517

float3 hcl2rgb(float3 HCL) {
    float3 RGB = 0;
    if (HCL.z != 0) {
        float H = HCL.x;
        float C = HCL.y;
        float L = HCL.z * __color_space_converters_HCLmaxL;
        float Q = exp((1 - C / (2 * L)) * (__color_space_converters_HCLgamma / __color_space_converters_HCLy0));
        float U = (2 * L - C) / (2 * Q - 1);
        float V = C / Q;
        float A = (H + min(frac(2 * H) / 4, frac(-2 * H) / 8)) * PI * 2;
        float T;
        H *= 6;
        if (H <= 0.999) {
            T = tan(A);
            RGB.r = 1;
            RGB.g = T / (1 + T);
        } else if (H <= 1.001) {
            RGB.r = 1;
            RGB.g = 1;
        } else if (H <= 2) {
            T = tan(A);
            RGB.r = (1 + T) / T;
            RGB.g = 1;
        } else if (H <= 3) {
            T = tan(A);
            RGB.g = 1;
            RGB.b = 1 + T;
        } else if (H <= 3.999) {
            T = tan(A);
            RGB.g = 1 / (1 + T);
            RGB.b = 1;
        } else if (H <= 4.001) {
            RGB.g = 0;
            RGB.b = 1;
        } else if (H <= 5) {
            T = tan(A);
            RGB.r = -1 / T;
            RGB.b = 1;
        } else {
            T = tan(A);
            RGB.r = 1;
            RGB.b = -T;
        }
        RGB = RGB * V + U;
    }
    return RGB;
}

float3 rgb2hcl(float3 RGB) {
    float3 HCL;
    float H = 0;
    float U = min(RGB.r, min(RGB.g, RGB.b));
    float V = max(RGB.r, max(RGB.g, RGB.b));
    float Q = __color_space_converters_HCLgamma / __color_space_converters_HCLy0;
    HCL.y = V - U;
    if (HCL.y != 0) {
        H = atan2(RGB.g - RGB.b, RGB.r - RGB.g) / PI;
        Q *= U / V;
    }
    Q = exp(Q);
    HCL.x = frac(H / 2 - min(frac(H), frac(-H)) / 6);
    HCL.y *= Q;
    HCL.z = lerp(-U, V, Q) / (__color_space_converters_HCLmaxL * 2);
    return HCL;
}

// ====== NSV <=> RGB ======
// Convert regular hue into visually normalised hue.
// TODO: Make this more inverse'y of nue2hue, this one is meh.
//       Also: find a easier fit to my dataa lol.
//             Piecewise linear should suffice tbh.
float hue2nue(float h) {
    float s,c;
    float res = 0.028209121631148908 +
              h * (1.1803248154476926 +
              h * (-0.30485848905412855 +
              h * 0.08021733797120657));
    h *= PI * 3;
    sincos(h, s, c);
    res += 0.0024769224086929934 * s - 0.020821866044909623 * c;
    sincos(2*h, s, c);
    res += -0.0028015999214360274 * s - 0.006050953813534282 * c;
    sincos(3*h, s, c);
    res += 0.002626077960893727 * s - 0.0013363017727050022 * c;
    return res;
}

float nue2hue(float h) {
    float s,c;
    float res = -0.039436603249164766 +
              h * (1.05040905784718 +
              h * (-0.2652260767297235 +
              h * 0.2854720562924914));
    h *= PI * 3;
    sincos(h, s, c);
    res += 0.006793208960551353 * s + 0.02816217860198669 * c;
    sincos(2*h, s, c);
    res += 0.003947381398372687 * s + 0.004109084544190795 * c;
    sincos(3*h, s, c);
    res += 0.0004901337904026853 * s + 0.007165340102987282 * c;
    return res;
}

float3 rgb2nsv(float3 col) {
    col = rgb2hsv(col);
    col.x = hue2nue(col.x);
    return col;
}

float3 nsv2rgb(float3 col) {
    col.x = nue2hue(col.x);
    return hsv2rgb(col);
}

#endif //COLOR_SPACE_CONVERTERS