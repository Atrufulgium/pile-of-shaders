// Defines a method to generate random palettes, and methods for discrete
// modifications of colours (presumably from the palette).

#ifndef ATRU_PALETTES
#define ATRU_PALETTES

// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles

#include "xoshiroplus.cginc"
#include "Distributions.cginc"
#include "ColorSpaces.cginc"

#ifndef PI
#define PI 3.1415926536
#endif

// Randomly choose from one of the below
#define PALETTE_ANY                 0

// Just one hue
#define PALETTE_MONOCHROMATIC       1

// Hue, hue + 180deg
#define PALETTE_COMPLEMENTARY       2

// Hue, hue + 150deg, hue + 210deg
#define PALETTE_SPLIT_COMPLEMENTARY 3
// Hue, hue - 30deg, hue + 30deg
#define PALETTE_ANALOGOUS           4
// Hue, hue + 120deg, hue + 240deg
#define PALETTE_TRIADIC             5

// Hue, hue + 60deg, hue + 180deg, hue + 240deg
#define PALETTE_TETRADIC_RECTANGLE  6
// Hue, hue + 90deg, hue + 180deg, hue + 270deg
#define PALETTE_TETRADIC_SQUARE     7

struct palette {
    // The colours of this palette, in nsv.
    // The .x are the first colour, the .y the second, etc.
    float4 n;
    float4 s;
    float4 v;
    // When changing up/down a shade of brightness,
    // also change up the hue by these amounts.
    float4 cool_delta;
    float4 warm_delta;
    // The actual number of colours in this palette.
    float num_cols;
};

// Create a random palette; it returns how many colours are in the palette,
// and they are put in the out values col1, ..., col4.
palette new_palette(inout rand32x4 r, float palette_type, float4 inrgb, float2 imitateSV) {
    float p_rand = sample_uniform(r, 1, 8);
    if (palette_type == 0)
        palette_type = floor(p_rand);
    
    // Get some base colour to work of off.
    // If we have a preset, use that instead.
    float4 degs = sample_uniform(r, 0, 1).xxxx;
    if (inrgb.a > 0) {
        inrgb.xyz = rgb2nsv(inrgb.xyz);
        degs = inrgb.xxxx;
    }
    
    // Apply the chosen palette to the base colour.
    // This is just "if (palette_type = BLAH) degs += float4(BLUH)".
    // Compacted for performance; in matrix form the compiler sees
    // simultaneous inner products happening here, which is less ops.
    float4x4 mat1 = {
        float4(0, 0.5, 0, 0),           // PALETTE_COMPLEMENTARY
        float4(0, 0.42, -0.42, 0),      // PALETTE_SPLIT_COMPLEMENTARY
        float4(0, 0.084, -0.084, 0),    // PALETTE_ANALOGOUS
        float4(0, 0.333, -0.333, 0)     // PALETTE_TRIADIC
    };
    float2x4 mat2 = {
        float4(0, 0.167, 0.5, 0.667),   // PALETTE_TETRADIC_RECTANGLE
        float4(0, 0.25, 0.5, 0.75)      // PALETTE_TETRADIC_SQUARE
    };
    float4 vec1 = palette_type == float4(
        PALETTE_COMPLEMENTARY,
        PALETTE_SPLIT_COMPLEMENTARY,
        PALETTE_ANALOGOUS,
        PALETTE_TRIADIC
    );
    float2 vec2 = palette_type == float2(
        PALETTE_TETRADIC_RECTANGLE,
        PALETTE_TETRADIC_SQUARE
    );
    degs += mul(vec1, mat1) + mul(vec2, mat2);
    degs = frac(degs);

    // Instead of using those colours, use those colours with some
    // small possible offset.
    float4 n = sample_circular_gaussian(r, degs, 0.05);

    // Sample (sat,val) together uniformly from the quarter annulus
    // of radii(small, almost-1) centered at (1,1). This because in the
    // far corner, most colours are similar and grayscale and in the
    // near corner, colours are too bright.
    // The sqrt is required for uniformity, as otherwise the points
    // would bunch up near the lower bound. Because of the sqrt, the
    // bounds are squared.
    float4 radius = sqrt(sample_uniform(r, 0.05*0.05, 0.75*0.75));
    float4 angle = sample_uniform(r, PI, PI * 3/2);
    float4 s,c;
    sincos(angle,s,c);
    float4 sat = 1 + radius * c;
    float4 val = 1 + radius * s;

    if (inrgb.a > 0) {
        // Remember that we're nsv already.
        n.x = inrgb.x;
        sat.x = inrgb.y;
        val.x = inrgb.z;
    }

    sat = (imitateSV.x) * sat.xxxx + (1 - imitateSV.x) * sat;
    val = (imitateSV.y) * val.xxxx + (1 - imitateSV.y) * val;

    // Actually create the palette struct.
    palette p;
    p.n = n;
    p.s = sat;
    p.v = val;

    // Precompute the delta values we'll be using when using palette shades.
    p.warm_delta = 0.05 + sample_exponential(r, 20);
    // We do NOT want the warm delta to move from cyan into blue.
    // This affects brightness way too much.
    // Similarly, orange to red is bad as well.
    p.warm_delta = ((p.n >= 0.665 || p.n < 0.165) * 2 - 1) * p.warm_delta;
    // cool_delta should mirror warm_delta as otherwise both ends would walk
    // of to the same hue which is a little awkward.
    // Moving to brighter hues here isn't a visible problem as we're also
    // dimming everything at that end significantly.
    p.cool_delta = p.warm_delta;

    p.num_cols = 1 + (palette_type >= 2) + (palette_type >= 3) + (palette_type >= 6);
    return p;
}

float3 dimmen_nsv(float3 nsvcol, float steps, float maxsteps) {
    float fraction = 1 - (steps/maxsteps);
    return nsvcol * float3(1, sqrt(fraction), fraction);
}

float3 brighten_nsv(float3 nsvcol, float steps, float maxsteps) {
    float fraction = steps/maxsteps;
    nsvcol.y *= (1 - fraction*fraction*0.5);
    nsvcol.z = nsvcol.z + (1 - nsvcol.z) * fraction;
    return nsvcol;
}

float3 palette_get_col(palette p, float col_id) {
    float3x4 colourmat = {p.n, p.s, p.v};
    return mul(colourmat, col_id == float4(0,1,2,3));
}

float3 palette_get_shade(palette p, float col_id, float shade, float shadecount) {
    float3 col = palette_get_col(p, col_id);

    shade += shadecount;
    // Dimmen to the left, brighten to the right.
    // This is not just value/saturation but also hue.
    // Hue only looks bad if we hueshift from
    //   cold into bright  (dimmen)
    //   bright into cold  (brighten)
    // But the former is not that noticable, as they're,
    // well, dimmed. We do need to prevent the latter
    // by just shifting the other way then though.
    // This is done in new_palette() for us already.
    float ratio = abs(shadecount - (shade + 1)) / (shadecount + 1);
    float cool_delta = dot(p.cool_delta, col_id == float4(0,1,2,3));
    float warm_delta = dot(p.warm_delta, col_id == float4(0,1,2,3));
    if (shade < shadecount) {
        col.x = frac(col.x - ratio * cool_delta);
        col = dimmen_nsv(col, shadecount - shade, shadecount + 1);
    } else {
        col.x = frac(col.x + ratio * warm_delta);
        col = brighten_nsv(col, (shade - shadecount), shadecount + 1);
    }
    return col;
}
// Shade in {-2, -1, 0, +1, +2}
float3 palette_get_shade(palette p, float col_id, float shade) {
    return palette_get_shade(p, col_id, shade, 2);
}

#endif //ATRU_PALETTES