#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;

float _Shrink;

float4 vert (appdata_base IN) : SV_POSITION {
    float4 world = mul(unity_ObjectToWorld, IN.vertex);
    world.xyz -= IN.normal * _Shrink;
    return  mul(UNITY_MATRIX_VP, world);
}

float _Thickness;
float _DotRange;

float4 _InnerColor;

fixed4 frag () : SV_Target {
    return float4(_InnerColor.rgb, 1);
}