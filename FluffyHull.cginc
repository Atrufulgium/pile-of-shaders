#include "UnityCG.cginc"
#include "Distributions.cginc"

// The including file must define a VertexInput2 struct.

struct TessFactors {
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

float _Detail;

TessFactors GetTessFactors(InputPatch<VertexInput2, 3> patch) {
	TessFactors f;
    // Edges are set to zero (see the big comment later in this file) so we
    // don't need that many vertices there.
    f.edge[0] = round(max(1, _Detail/4));
    f.edge[1] = round(max(1, _Detail/4));
    f.edge[2] = round(max(1, _Detail/4));
	f.inside = _Detail;
	return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("GetTessFactors")]
VertexInput2 hull(
    InputPatch<VertexInput2, 3> patch,
    uint id : SV_OUTPUTCONTROLPOINTID
) {
    return patch[id];
}

float4 _Direction;
float _Variance;
float _Phong_Mesh_Smoothing;

#define DOMAIN_INTERPOLATE(fieldName) v.fieldName \
    = patch[0].fieldName * bary.x \
    + patch[1].fieldName * bary.y \
    + patch[2].fieldName * bary.z;

// Interpolates the entire VertexInput2 struct. The GPU doesn't do it manually
// for domain shaders. (Which I guess can be nice?)
VertexInput2 Interpolate(
    TessFactors factors,
	OutputPatch<VertexInput2, 3> patch,
	float3 bary
) {
    VertexInput2 v;

    DOMAIN_INTERPOLATE(vertex);
    // Smoothed phong tesselation
    float3 phong[3];
    [unroll]
    for (int i = 0; i < 3; i++) {
        float offset = dot(v.vertex.xyz, patch[i].normal)
                     - dot(patch[i].vertex.xyz, patch[i].normal);
        phong[i] = v.vertex.xyz - patch[i].normal * offset;
    }
    float3 pvert = phong[0] * bary.x
                 + phong[1] * bary.y
                 + phong[2] * bary.z;
    v.vertex.xyz = (1 - _Phong_Mesh_Smoothing) * v.vertex.xyz
                 + _Phong_Mesh_Smoothing * pvert;

    // Regular interpolation from here on out.
    // The struct layout across various passes is quite different.
    // Ignoring any instancing data as that's incompatible anyway.
    DOMAIN_INTERPOLATE(normal)
    // I don't see other code do this step, but it is needed if you want
    // zero error. Without this, it would usually be a tiny bit wrong.
    v.normal = normalize(v.normal);
    DOMAIN_INTERPOLATE(uv0)

    #if defined(FLUFFY_FORWARD_PASS) || defined(FLUFFY_ADD_PASS)
        DOMAIN_INTERPOLATE(uv1)
        #if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
            DOMAIN_INTERPOLATE(uv2)
        #endif
    #endif
    #ifdef _USE_MODEL_TANGENTS
        DOMAIN_INTERPOLATE(tangent)
    #endif

    return v;
}

// Computes vertex properties from the domain info.
VertexInput2 GetVertex(
    TessFactors factors,
	OutputPatch<VertexInput2, 3> patch,
	float3 bary,
    uint id1
) {
    VertexInput2 v = Interpolate(factors, patch, bary);

    // Generate a random number based on the overall original tri we're working
    // with (SV_PRIMITIVEID), and the barycentric coords. This gives a unique
    // unchanging seed for this vertex.
    //
    // Do note that we need vertices at the same spot to generate the same seed
    // as otherwise we get holes in our model. Previously I used model space.
    // Model space does not work as armatures pre-empt even them, so if you'd
    // use them and move the bones all rng would change. Other spaces make even
    // less sense.
    // I sort-of fix this by just setting the edges to 0. Yes, this is giving
    // up, but it's not *that* obvious most of the time.
    uint4 id = uint4(round(1234567 * bary + 1), 230);
    id.x ^= id1 * 1234567890;
    // This id is still quite a bit too predictable for the rng, so a hack:
    id ^= id.zxyw;
    rand32x4 rng = new_rand32x4(id);
    float maxLength = _Direction.w * 0.01;
    float length = clamp(sample_exponential(rng, 5 / maxLength).x, 0, maxLength);
    if (any(bary == 0 || bary == 1))
        length = 0;

    // Compute a tangent basis in order to be able to work with fur direction.
    float3 tangentCoeffs = normalize(_Direction.xyz);
    float3 normal = v.normal;
    float3 tangent;
    #if defined(_USE_MODEL_TANGENTS)
        tangent = v.tangent;
    #else
        tangent = float3(normal.y, -normal.x, normal.z); // lin indep from normal, now do gramm schmidt
        tangent = normalize(tangent - dot(normal, tangent)*normal);
    #endif
    float3 bitangent = cross(normal, tangent);

    // TODO: Maybe use tri size to scale the local coordinate system?
    // That'll give weird inconsistent lengths though.
    // Hairy ball theorem's also being a jerk, singularities don't behave
    // nicely with normals.
    float3 offset = tangent * tangentCoeffs.x
                   + normal * tangentCoeffs.y
                + bitangent * tangentCoeffs.z;

    // Add some variance
    // TODO: Smooth this over nearby values as otherwise you get ugly planes.
    // (Though doing that is stupid expensive, sigh.)
    float3 varianceOffset = sample_uniform_sphere(rng) * _Variance * 0.01;
    offset += varianceOffset;
    offset = normalize(offset) * length;

    v.vertex.xyz += offset;
    return v;
}