// See https://vigna.di.unimi.it/xorshift/ , xoshiro128+
// Defines rand32 and rand32x4 structs with initialisable state:
//   rand32[x4] new_rand32[x4]()
//   rand32[x4] new_rand32[x4](uint)
//   ...
//   rand32[x4] new_rand32[x4](uint, uint, uint, uint)
//   rand32[x4] new_rand32[x4](float)
//   ...
//   rand32 new_rand32(float, float, float, float)
// which can be used to sample random numbers:
//   uint[4] next(rand32[x4])              // Uniform over the 2^32 uints.
//   float[4] nextfloat01(rand32[x4])      // Uniform over some float values in [0,1).
// rand32's state is not allowed to be fully 0, but the chances of this
// are 1/2^128. The lowest four bits in `uint next()` have a visible,
// plottable dependency, sometimes, apparantly.
// Initialisation is somewhat expensive.

// ALWAYS pass the structs with `inout` to maintain the state after calls.
// Otherwise you're just repeatedly getting the same "random" number(s).

#ifndef XOSHIROPLUS
#define XOSHIROPLUS

#define INIT_ITER 1

struct rand32 {
    uint state0;
    uint state1;
    uint state2;
    uint state3;
};

struct rand32x4 {
    uint4 state0;
    uint4 state1;
    uint4 state2;
    uint4 state3;
};

uint __x128p_rotl(uint x, int k) {
    return (x << k) | (x >> (32 - k));
}

uint4 __x128p_rotl(uint4 x, int k) {
    return (x << k) | (x >> (32 - k));
}

uint next(inout rand32 r) {
    uint t = r.state1 << 9;

    r.state2 ^= r.state0;
    r.state3 ^= r.state1;
    r.state1 ^= r.state2;
    r.state0 ^= r.state3;

    r.state2 ^= t;
    r.state3 = __x128p_rotl(r.state3, 11);

    return r.state0 + r.state3;
}
uint4 next(inout rand32x4 r) {
    uint4 t = r.state1 << 9;

    r.state2 ^= r.state0;
    r.state3 ^= r.state1;
    r.state1 ^= r.state2;
    r.state0 ^= r.state3;

    r.state2 ^= t;
    r.state3 = __x128p_rotl(r.state3, 11);
    
    return r.state0 + r.state3;
}

float nextfloat01(inout rand32 r) {
    uint res = next(r);
    // Bit pattern [sign = 0] [exponent = 0111 1111] [mantissa]
    // results in 2^23 values living in [1,2), uniformly.
    // The lowest four bits have correlations. Not too significant,
    // but we want them gone. We're wasting 9 bits, so we can
    // just shift those four troublemakers away and OR with the 1 in
    // the right place instead of that AND mentioned above.
    return asfloat((res >> 9) | 0x3F800000) - 1.0;
}
float4 nextfloat01(inout rand32x4 r) {
    uint4 res = next(r);
    return asfloat((res >> 9) | 0x3F800000) - 1.0;
}

rand32 new_rand32(uint state0, uint state1, uint state2, uint state3) {
    rand32 r;
    // Init with some apparant randomness (which is not really a
    // thing though). This has a small chance of having "mainly"
    // zeroes that make the initial iterations obviously nonrandom.
    // Inits will never be fully zero with the |.

    // Some other magic to make it appear noisy even early on with
    // seeds very close together.
    // This definitely violates Knuth's "don't do random stuff
    // to create randomness" but oh well.
    r.state0 = __x128p_rotl(state0 ^ 3141592653, 31) ^ state1;
    r.state1 = __x128p_rotl(state1 ^  589793238, 25) ^ state2;
    r.state2 = __x128p_rotl(state2 ^  462643383, 31) ^ state3;
    r.state3 = __x128p_rotl(state3 ^ 2795028841, 25) ^ state0;
    r.state3 |= 2147483648;
    // Modify state a bit to make initial zeroes not obvious.
    [unroll]
    for (int i = 0; i < INIT_ITER; i++)
        next(r);
    return r;
}
rand32 new_rand32(float state0, float state1, float state2, float state3) {
    return new_rand32(asuint(state0), asuint(state1), asuint(state2), asuint(state3));
}
rand32 new_rand32(uint state0, uint state1, uint state2) {
    return new_rand32(state0, state1, state2, 1u);
}
rand32 new_rand32(float state0, float state1, float state2) {
    return new_rand32(state0, state1, state2, 1.);
}
rand32 new_rand32(uint state0, uint state1) {
    return new_rand32(state0, state1, 0u, 1u);
}
rand32 new_rand32(float state0, float state1) {
    return new_rand32(state0, state1, 0., 1.);
}
rand32 new_rand32(uint state0) {
    return new_rand32(state0, 0u, 0u, 1u);
}
rand32 new_rand32(float state0) {
    return new_rand32(state0, 0., 0., 1.);
}
rand32 new_rand32() {
    return new_rand32(0u, 0u, 0u, 1u);
}

rand32x4 new_rand32x4(uint state0, uint state1, uint state2, uint state3) {
    rand32x4 r;
    uint4 state = float4(
        __x128p_rotl(state0 ^ 3141592653, 31) ^ state1,
        __x128p_rotl(state1 ^  589793238, 25) ^ state2,
        __x128p_rotl(state2 ^  462643383, 31) ^ state3,
        __x128p_rotl(state3 ^ 2795028841, 25) ^ state0
    );
    // Need to create some more states
    r.state0 = state;
    r.state1 = state.yzwx ^ 0x00FF00FF;
    r.state2 = state.zwxy ^ 0xFF00FF00;
    r.state3 = state.wxyz ^ 0xFFFF0000;
    r.state3 |= 2147483648;
    // Modify state a bit to make initial zeroes not obvious.
    [unroll]
    for (int i = 0; i < INIT_ITER; i++)
        next(r);
    return r;
}
rand32x4 new_rand32x4(float state0, float state1, float state2, float state3) {
    return new_rand32x4(asuint(state0), asuint(state1), asuint(state2), asuint(state3));
}
rand32x4 new_rand32x4(uint state0, uint state1, uint state2) {
    return new_rand32x4(state0, state1, state2, 1u);
}
rand32x4 new_rand32x4(float state0, float state1, float state2) {
    return new_rand32x4(state0, state1, state2, 1.);
}
rand32x4 new_rand32x4(uint state0, uint state1) {
    return new_rand32x4(state0, state1, 0u, 1u);
}
rand32x4 new_rand32x4(float state0, float state1) {
    return new_rand32x4(state0, state1, 0., 1.);
}
rand32x4 new_rand32x4(uint state0) {
    return new_rand32x4(state0, 0u, 0u, 1u);
}
rand32x4 new_rand32x4(float state0) {
    return new_rand32x4(state0, 0., 0., 1.);
}
rand32x4 new_rand32x4() {
    return new_rand32x4(0u, 0u, 0u, 1u);
}

#endif //XOSHIROPLUS