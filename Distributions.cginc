// Defines functions to sample from different distributions.
// Passing a rand32 results in one float of that distribution,
// and passing a rand32x4 results in four.
// Neglecting the first rand32/rand32x4 argument, these are:
//   sample_uniform([left=0, right=1])
//   sample_exponential(lambda)
//   sample_gaussian(mean, sigma)
//     (has "sample_normal" as synonym)
//   sample_circular_gaussian(mean, sigma)
//     (has "sample_circular_normal" as synonym)
//   sample_kumaraswamy(a, b[, left=0, right=1])
//
// The following methods are a bit special in that their return
// is always just one thing, no matter if you pass rand32 or
// rand32x4. The latter is still better though, as it uses less
// instructions.
//   sample_uniform_circle() : float2
//     (has "sample_uniform_S1" as synonym)
//   sample_uniform_sphere() : float3
//     (has "sample_uniform_S2" as synonym)
//   sample_uniform_S3() : float4

#ifndef ATRU_DISTR
#define ATRU_DISTR

#include "xoshiroplus.cginc"

// Due to implementation details, most of these are only accurate for <<2^23.

// Sample a Uniform[left,right).
float sample_uniform(inout rand32 r, float left, float right) {
    return nextfloat01(r) * (right - left) + left;
}
float4 sample_uniform(inout rand32x4 r, float4 left, float4 right) {
    return nextfloat01(r) * (right - left) + left;
}
// Sample a Uniform[0,1)
float sample_uniform(inout rand32 r) {
    return nextfloat01(r);
}
float4 sample_uniform(inout rand32x4 r) {
    return nextfloat01(r);
}

// Sample a Exp(lambda).
float sample_exponential(inout rand32 r, float lambda) {
    float u = nextfloat01(r);
    u += u == 0;
    // 1 - [0,1) gives no 0 so no broken log.
    return -log(1 - u)/lambda;
}
float4 sample_exponential(inout rand32x4 r, float4 lambda) {
    float4 u = nextfloat01(r);
    u += u == 0;
    return -log(1 - u)/lambda;
}

// Sample a N(mu, sigma^2)
float sample_gaussian(inout rand32 r, float mean, float sigma) {
    // Box-Muller
    float u1 = nextfloat01(r);
    // Make it (0,1] instead of [0,1) so the log doesn't break.
    u1 += u1 == 0;
    float u2 = nextfloat01(r);
    return mean + sigma * (sqrt(-2 * log(u1)) * cos(u2 * 6.283185));
}
float4 sample_gaussian(inout rand32x4 r, float4 mean, float4 sigma) {
    float4 u1 = nextfloat01(r);
    u1 += u1 == 0;
    float4 u2 = nextfloat01(r);
    return mean + sigma * (sqrt(-2 * log(u1)) * cos(u2 * 6.283185));
}
float sample_normal(inout rand32 r, float mean, float sigma) {
    return sample_gaussian(r, mean, sigma);
}
float4 sample_normal(inout rand32x4 r, float4 mean, float4 sigma) {
    return sample_gaussian(r, mean, sigma);
}

// Approximation of an approximation.
// Want something like Von Mises, but that's a pain.
// So instead just do gaussian mod 1.
float sample_circular_gaussian(inout rand32 r, float mean, float sigma) {
    return frac(sample_gaussian(r, mean, sigma));
}
float4 sample_circular_gaussian(inout rand32x4 r, float4 mean, float4 sigma) {
    return frac(sample_gaussian(r, mean, sigma));
}
float sample_circular_normal(inout rand32 r, float mean, float sigma) {
    return sample_circular_gaussian(r, mean, sigma);
}
float4 sample_circular_normal(inout rand32x4 r, float4 mean, float4 sigma) {
    return sample_circular_gaussian(r, mean, sigma);
}

// See https://en.wikipedia.org/wiki/Kumaraswamy_distribution, also
// for the formula for implementation.
// It's a nice distribution that can look both beta-like, and like a
// distribution that can have mass in both extremes.
float sample_kumaraswamy(inout rand32 r, float a, float b) {
    float u = nextfloat01(r);
    return pow(1 - pow(1-u, 1/b), 1/a);
}
float4 sample_kumaraswamy(inout rand32x4 r, float4 a, float4 b) {
    float4 u = nextfloat01(r);
    return pow(1 - pow(1-u, 1/b), 1/a);
}
// Kumaraswamy has support in [0,1], so overloads to scale that to anywhere.
float sample_kumaraswamy(inout rand32 r, float a, float b, float left, float right) {
    return sample_kumaraswamy(r, a, b) * (right - left) + left;
}
float4 sample_kumaraswamy(inout rand32x4 r, float4 a, float4 b, float4 left, float4 right) {
    return sample_kumaraswamy(r, a, b) * (right - left) + left;
}

// Now for the distributions on Sn

float2 __sample_uniform_circle(float angle) {
    float s,c;
    sincos(angle, s, c);
    return float2(s, c);
}
float2 sample_uniform_circle(rand32 r) {
    return __sample_uniform_circle(next(r));
}
float2 sample_uniform_circle(rand32x4 r) {
    return __sample_uniform_circle(next(r).x);
}
float2 sample_uniform_S1(rand32 r) {
    return sample_uniform_circle(r);
}
float2 sample_uniform_S1(rand32x4 r) {
    return sample_uniform_circle(r);
}

// https://math.stackexchange.com/a/3322169
// Rejection sampling also exists, but eh... too branchy.
float3 __sample_uniform_sphere(float3 gaussian) {
    return normalize(gaussian);
}
float3 sample_uniform_sphere(rand32 r) {
    return __sample_uniform_sphere(float3(sample_gaussian(r,0,1), sample_gaussian(r,0,1), sample_gaussian(r,0,1)));
}
float3 sample_uniform_sphere(rand32x4 r) {
    return __sample_uniform_sphere(sample_gaussian(r,0,1).xyz);
}
float3 sample_uniform_S2(rand32 r) {
    return sample_uniform_sphere(r);
}
float3 sample_uniform_S2(rand32x4 r) {
    return sample_uniform_sphere(r);
}

float4 __sample_uniform_S3(float4 gaussian) {
    return normalize(gaussian);
}
float4 sample_uniform_S3(rand32 r) {
    return __sample_uniform_S3(float4(sample_gaussian(r,0,1), sample_gaussian(r,0,1), sample_gaussian(r,0,1), sample_gaussian(r,0,1)));
}
float4 sample_uniform_S3(rand32x4 r) {
    return __sample_uniform_S3(sample_gaussian(r,0,1));
}

#endif //ATRU_DISTR