#ifndef FXMATH_H
#define FXMATH_H

/* Q16.16 fixed-point math for a core with no multiplier.
 * Needs uint32_t / int32_t defined before inclusion.
 * No '*', '/' or '%' on variables: the build has no libgcc. */

static uint32_t fx_umul(uint32_t a, uint32_t b)
{
    uint32_t r = 0u;
    while (b != 0u) {
        if ((b & 1u) != 0u)
            r = r + a;
        a = a << 1;
        b = b >> 1;
    }
    return r;
}

static const int32_t fx_atan[16] = {
    823550, 486170, 256879, 130396, 65451, 32757, 16383, 8192,
    4096, 2048, 1024, 512, 256, 128, 64, 32
};

#define FX_CORDIC_K   636751
#define FX_LN2        45426
#define FX_DEG2RAD64  1171271

static void fx_cordic(int32_t z, int32_t *c, int32_t *s)
{
    int32_t x = FX_CORDIC_K;
    int32_t y = 0;
    int32_t t;
    int i;

    for (i = 0; i < 16; i = i + 1) {
        if (z >= 0) {
            t = x - (y >> i);
            y = y + (x >> i);
            x = t;
            z = z - fx_atan[i];
        } else {
            t = x + (y >> i);
            y = y - (x >> i);
            x = t;
            z = z + fx_atan[i];
        }
    }
    *c = x;
    *s = y;
}

/* CORDIC runs in Q20 (4 guard bits); results are rounded to Q16.
 * degrees 0..359 -> cos and sin in Q16.16 */
static void fx_cossin_deg(uint32_t d, int32_t *cosv, int32_t *sinv)
{
    uint32_t q = 0u;
    int32_t c, s, z;

    while (d >= 90u) {
        d = d - 90u;
        q = q + 1u;
    }
    z = (int32_t)(fx_umul(d, FX_DEG2RAD64) >> 6);
    fx_cordic(z, &c, &s);
    c = (c + 8) >> 4;
    s = (s + 8) >> 4;

    switch (q & 3u) {
    case 0u: *cosv = c;  *sinv = s;  break;
    case 1u: *cosv = -s; *sinv = c;  break;
    case 2u: *cosv = -c; *sinv = -s; break;
    default: *cosv = s;  *sinv = -c; break;
    }
}

/* log2(x) in Q16.16, x >= 1 */
static uint32_t fx_log2(uint32_t x)
{
    uint32_t n = 0u;
    uint32_t t = x;
    uint32_t m, f = 0u;
    int i;

    while (t > 1u) {
        t = t >> 1;
        n = n + 1u;
    }
    if (n >= 15u)
        m = x >> (n - 15u);
    else
        m = x << (15u - n);

    for (i = 0; i < 16; i = i + 1) {
        m = fx_umul(m, m) >> 15;
        f = f << 1;
        if (m >= 65536u) {
            f = f | 1u;
            m = m >> 1;
        }
    }
    return (n << 16) + f;
}

/* ln(x) in Q16.16, x >= 1 */
static uint32_t fx_ln(uint32_t x)
{
    uint32_t l = fx_log2(x);
    uint32_t hi = l >> 8;
    uint32_t lo = l & 255u;
    return (fx_umul(hi, FX_LN2) >> 8) + (fx_umul(lo, FX_LN2) >> 16);
}

#endif
