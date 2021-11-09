float width;
float seed;

int _PaletteType;
float _RandomPalette;
float4 _BaseColor;
float _ImitateS;
float _ImitateV;

float _Grayscale;

#include "xoshiroplus.cginc"
#include "Distributions.cginc"
#include "ColorSpaces.cginc"
#include "PaletteGenerator.cginc"

fixed4 frag(float2 uv : TEXCOORD0) : SV_Target {
    float height = 4;

    // Passing 0 to create_palette gives a random one.
    if (_RandomPalette)
        _PaletteType = PALETTE_ANY;

    float2 pixel = floor(float2(2*width+1, height)*uv);
    rand32x4 r = new_rand32x4(seed);
    palette p = new_palette(r, _PaletteType, _BaseColor, float2(_ImitateS, _ImitateV));

    pixel = floor(float2(2*width+1, p.num_cols)*uv);
    float3 col = palette_get_shade(p, pixel.y, pixel.x - width, width);
    
    col = nsv2rgb(col);
    if (_Grayscale)
        col = rgb2gray(col);
    
    return float4(col, 1);
}