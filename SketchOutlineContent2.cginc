#pragma vertex vert
#pragma geometry geom
#pragma fragment frag

#include "UnityCG.cginc"
#include "xoshiroplus.cginc"

/* This shader works by creating quads where previously edges of tris lied.
 * This happens in clipspace post-perspective-division because we want those
 * lines to be perfectly nicely on the screen and not angled.
 *
 * However, we don't draw the diagonals of right-angle triangles, because
 * those happen basically only in quads. To check this, we need worldspace.
 *
 * In addition, usually you wouldn't care about points behind the camera in
 * cameraspace because the GPU handles all of that for you. However, I'm doing
 * stuff with those vertices, and creating quads from _wrong_ coords creates
 * wrong quads the GPU won't fix for me. So in cameraspace, we need to, by
 * hand, clip the vertices s.t. they aren't behind the camera anymore. So this
 * requires some cameraspace manipulations.
 *
 * However, those cameraspace manipulations can yeet points way out there. So,
 * again, we need to clip the vertices, this time to a little further than the
 * edge of the screen. Sheesh.
 *
 * Good exercise in definitely, fully understanding all coordinate systems even
 * if I thought I knew them already.
 */

struct v2g {
    float4 worldPos : SV_POSITION;
    // wait what this is allowed?
    nointerpolation uint id : TEXCOORD0;
};

struct g2f {
    float4 pos : SV_POSITION;
    // xy: regular uv
    // z: length of this line in clipspace
    // w: length of this line in pixels
    float4 uv : TEXCOORD0;
    nointerpolation uint id : TEXCOORD1;
};

sampler2D _MainTex;
float4 _MainTex_ST;

v2g vert (float4 vertex : POSITION, uint id : SV_VERTEXID) {
    v2g o;
    o.worldPos = mul(unity_ObjectToWorld, vertex);
    o.id = id;
    return o;
}

float _Thickness;
float _DotRange;

// Clip a cameraspace line to the view frustrum's near plane because
// points behind the camera get screwed over pretty hard.
// (Points beyond the far plane are fine and need no processing.)
void clipNearPlane(inout float4 p1, inout float4 p2) {
    // Who needs _ProjectionParams.y if you can just hardcode it lol.
    float nearPlane = -0.1;
    // Note to self: negative z is further away. Unless it isn't,
    // but I'm not worrying about opengl vs directx.
    // "Works on my machine" letsgo

    // When this is called, it is guaranteed that at least one of
    // the point lies in the visible half.
    if (p1.z < nearPlane) {

        // Now do what the function says it does
        float4 tangent = p1 - p2;
        float dist = (nearPlane - p2.z) / tangent.z;
        if (p2.z > nearPlane)
            p2 = p2 + dist * tangent;

    } else /*if (p2.z < nearPlane)*/ {

        // Now do what the function says it does
        float4 tangent = p2 - p1;
        float dist = (nearPlane - p1.z) / tangent.z;
        if (p1.z > nearPlane)
            p1 = p1 + dist * tangent;

    }
}

// Clip a screenspace line to a space just slightly larger than
// the screen. If one point has screenspace (0.5,0.5) and the
// other (-100, 0.5), the uvs will be weird and we don't want
// that, so put the other at like (-1.1, 0.5).
void clipScreen(inout float4 p1, inout float4 p2) {
    float boundary = 1.1;
    // Simply check all four sides of the square and do intersections.
    // This code assumes that at least one point lies within the screen.
    float4 tangent = p2 - p1;
    float2 vec = float2(p1.x, p2.x);
    float2 dist = (sign(vec) * boundary - vec) / tangent.x;
    if (abs(p1.x) > boundary) {
        p1 = p1 + dist.x * tangent;
    } else if (abs(p2.x) > boundary) {
        p2 = p2 + dist.y * tangent;
    }

    tangent = p2 - p1;
    vec = float2(p1.y, p2.y);
    dist = (sign(vec) * boundary - vec) / tangent.y;

    if (abs(p1.y) > boundary) {
        p1 = p1 + dist.x * tangent;
    } else if (abs(p2.y) > boundary) {
        p2 = p2 + dist.y * tangent;
    }
}

// p1 and p2 should be cameraspace coords
void drawLine(float4 p1, float4 p2, uint id, inout TriangleStream<g2f> triStream) {
    clipNearPlane(p1, p2);
    // Now go from cameraspace to perspective'd screenspace
    p1 = mul(UNITY_MATRIX_P, p1);
    p1 /= p1.w;
    p2 = mul(UNITY_MATRIX_P, p2);
    p2 /= p2.w;
    
    // Make sure the resulting points aren't at like (-100,0.5,z,1) in
    // screenspace by clipping x,y to a little more than [-1,1]^2.
    clipScreen(p1, p2);

    // Only care about screenspace, so only look at x,y
    float4 tangent = float4(normalize((float2)(p2 - p1)), 0, 0);
    float4 binormal = float4(-tangent.y, tangent.x, 0, 0);
    tangent *= _Thickness * 0.5;
    binormal *= _Thickness * 0.5;

    float lenCl = length((float2)(p1 - p2));
    // Note clipspace's ranges are [-1,1].
    float lenPx = length(((float2)(p1 - p2) + float2(1,1))/2 * _ScreenParams.xy);

    // Further away it should poke out less
    //tangent *= lenCl;

    g2f o;
    o.id = id;

    o.pos = p1 - tangent + binormal;
    o.uv = float4(0,0, lenCl, lenPx);
    triStream.Append(o);
    o.pos = p1 - tangent - binormal;
    o.uv.xy = float2(1,0);
    triStream.Append(o);
    o.pos = p2 + tangent + binormal;
    o.uv.xy = float2(0,1);
    triStream.Append(o);
    o.pos = p2 + tangent - binormal;
    o.uv.xy = float2(1,1);
    triStream.Append(o);
    triStream.RestartStrip();
}

[maxvertexcount(12)]
void geom(triangle v2g IN[3], inout TriangleStream<g2f> triStream) {
    float nearPlane = -0.1;
    float4 worldPos[3];
    worldPos[0] = IN[0].worldPos;
    worldPos[1] = IN[1].worldPos;
    worldPos[2] = IN[2].worldPos;

    // Right-angle checking -- then don't draw the hypothenuse
    // because it's extremely likely part of a quad.
    // This also stops extremely thin triangles from spamming lines.
    // (See e.g. the top of the Unity material preview sphere.)
    float3 side1 = normalize((float3)(worldPos[1] - worldPos[0]));
    float3 side2 = normalize((float3)(worldPos[2] - worldPos[0]));
    float3 side3 = normalize((float3)(worldPos[2] - worldPos[1]));
    float p0isRightAngle = abs(dot(side1, side2)) < _DotRange;
    float p1isRightAngle = abs(dot(side1, side3)) < _DotRange;
    float p2isRightAngle = abs(dot(side2, side3)) < _DotRange;

    // Go to cameraspace.
    // Yes, "worldPos[i]" is a bit of a misnomer after this, but eh.
    [unroll]
    for (int i = 0; i < 3; i++)
        worldPos[i] = mul(UNITY_MATRIX_V, worldPos[i]);

    // If we don't check this, we pull lines from behind the camera
    // to barely in front, which is annoying and incorrect.
    bool3 inView = float3(worldPos[0].z, worldPos[1].z, worldPos[2].z) < nearPlane;

    if (!p2isRightAngle && any(inView.xy))
        drawLine(worldPos[0], worldPos[1], IN[0].id, triStream);
    if (!p0isRightAngle && any(inView.yz))
        drawLine(worldPos[1], worldPos[2], IN[1].id, triStream);
    if (!p1isRightAngle && any(inView.xz))
        drawLine(worldPos[0], worldPos[2], IN[2].id, triStream);
}

float4 _OuterColor;
float _UpdateSpeed;
sampler2D _LineTex;

fixed4 frag (g2f i) : SV_Target {
    float size = i.uv.z;
    float4 texToUse = float4(size > 1, 1 >= size && size > 0.5, 0.5 >= size && size > 0.25, 0.25 >= size);
    rand32x4 r = new_rand32x4(frac(i.id), round(_Time.y * _UpdateSpeed));
    float image = round(8 * nextfloat01(r).xy);
    float4 c = tex2D(_LineTex, (i.uv.xy + image) * float2(0.125, 1));
    float color = dot(texToUse, c);
    return float4(_OuterColor.rgb * color, color);
}