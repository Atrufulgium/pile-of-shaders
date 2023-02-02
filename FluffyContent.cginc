#if defined(_TANGENT_TO_WORLD) && !defined(_USE_MODEL_TANGENTS)
    #define _USE_MODEL_TANGENTS
#endif

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityStandardCoreForward.cginc"

// Modified from UnityStandardCoreForward to have tangents more often.
// Casting VertexInput2 → VertexInput will always succeed as the former is
// a superset of the latter no matter the shader keywords.
struct VertexInput2 {
    float4 vertex   : POSITION;
    half3 normal    : NORMAL;
    float2 uv0      : TEXCOORD0;
    float2 uv1      : TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    float2 uv2      : TEXCOORD2;
#endif
#ifdef _USE_MODEL_TANGENTS
    half4 tangent   : TANGENT;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#include "FluffyHull.cginc"

VertexInput2 vert(VertexInput2 v) {
    return v;
}

[UNITY_domain("tri")]
#if defined(FLUFFY_FORWARD_PASS)
    VertexOutputForwardBase
#elif defined(FLUFFY_ADD_PASS)
    VertexOutputForwardAdd
#endif
domain(
	TessFactors factors,
	OutputPatch<VertexInput2, 3> patch,
	float3 bary : SV_DomainLocation,
    uint id : SV_PRIMITIVEID
) {
    VertexInput2 v = GetVertex(factors, patch, bary, id);

    #if defined(FLUFFY_FORWARD_PASS)
        return vertForwardBase((VertexInput)v);
    #elif defined(FLUFFY_ADD_PASS)
        return vertForwardAdd((VertexInput)v);
    #endif
}

#if defined(FLUFFY_FORWARD_PASS)
float4 frag(VertexOutputForwardBase i) : SV_Target {
    return fragForwardBaseInternal(i);
}
#elif defined(FLUFFY_ADD_PASS)
float4 frag(VertexOutputForwardAdd i) : SV_Target {
    return fragForwardAddInternal(i);
}
#endif