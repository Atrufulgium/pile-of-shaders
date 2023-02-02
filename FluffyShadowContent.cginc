#if defined(UNITY_STANDARD_USE_SHADOW_UVS) && defined(_PARALLAXMAP) && !defined(_USE_MODEL_TANGENTS)
    #define _USE_MODEL_TANGENTS
#endif

// Somewhy this order (UnityCG first) is necessary for cubemapping shadows to
// work. Dunno why. ¯\_(ツ)_/¯
#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityStandardShadow.cginc"

// Modified from UnityStandardShadow to have tangents more often.
// Casting VertexInput2 → VertexInput will always succeed as the former is
// a superset of the latter no matter the shader keywords.
struct VertexInput2 {
    float4 vertex   : POSITION;
    float3 normal   : NORMAL;
    float2 uv0      : TEXCOORD0;
    #if defined(_USE_MODEL_TANGENTS)
        half4 tangent   : TANGENT;
    #endif
};


#include "FluffyHull.cginc"

VertexInput2 vert(
    VertexInput2 v
) {
    return v;
}

[UNITY_domain("tri")]
void domain(
	TessFactors factors,
	OutputPatch<VertexInput2, 3> patch,
	float3 bary : SV_DomainLocation,
    uint id : SV_PRIMITIVEID
    
    , out float4 opos : SV_POSITION
    #ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
    , out VertexOutputShadowCaster o
    #endif
    #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
    , out VertexOutputStereoShadowCaster os
    #endif
) {
    VertexInput2 v = GetVertex(factors, patch, bary, id);
    
    vertShadowCaster(
        (VertexInput)v

        , opos
        #ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
        , o
        #endif
        #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
        , os
        #endif
    );
}