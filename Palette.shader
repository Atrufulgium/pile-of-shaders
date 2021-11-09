Shader "Custom/Palette"
{
    Properties
    {
        [Header(Properties)]
        seed("Seed", Range(0,1)) = 0
        [IntRange] width("Shades", Range(1,64)) = 0
        [Enum(Monochromatic,1,Complementary,2,Split Complementary,3,Analogous,4,Triadic,5,Tetradic Rectangle,6,Tetradic Square,7)]
        _PaletteType("Palette Type", Int) = 1
        [Toggle] _RandomPalette("      (Use random type instead)", Float) = 0

        [Header(Color)]
        _BaseColor("Base Colour (RNG if alpha 0)", Color) = (0,0,0,0)
        _ImitateS("Imitate Base Saturation", Range(0,1)) = 0
        _ImitateV("Imitate Base Value", Range(0,1)) = 0

        [Header(Debug)]
        [Toggle] _Grayscale("Grayscale", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "RenderType"="Opaque"
            "PreviewType"="Plane"
        }
        Cull Off
        Lighting Off
        Zwrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (float4 vertex : POSITION, float2 uv : TEXCOORD0) {
                v2f o;
                o.vertex = UnityObjectToClipPos(vertex);
                o.uv = uv;
                return o;
            }
            #include "PaletteContent.cginc"
            ENDCG
        }
    }
}
