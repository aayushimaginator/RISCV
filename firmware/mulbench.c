typedef unsigned int uint32_t;
typedef unsigned char uint8_t;

#define LED_REG    (*(volatile uint32_t *)0x10000000u)
#define UART_DATA  (*(volatile uint32_t *)0x10000004u)
#define UART_STAT  (*(volatile uint32_t *)0x10000008u)
#define SEG_DATA   (*(volatile uint32_t *)0x1000000Cu)
#define SEG_DP     (*(volatile uint32_t *)0x10000010u)
#define CYCLE      (*(volatile uint32_t *)0x10000014u)
#define MUL_A      (*(volatile uint32_t *)0x10000020u)
#define MUL_B      (*(volatile uint32_t *)0x10000024u)
#define MUL_LO     (*(volatile uint32_t *)0x10000028u)
#define MUL_HI     (*(volatile uint32_t *)0x1000002Cu)
#define MUL_STAT   (*(volatile uint32_t *)0x10000030u)

#include "mulexp.h"

#define BENCH_N 100u

static void uart_putc(uint8_t c)
{
    while ((UART_STAT & 1u) != 0u) {
    }
    UART_DATA = (uint32_t)c;
}

static void pstr(const char *s)
{
    while (*s != 0) {
        uart_putc((uint8_t)*s);
        s = s + 1;
    }
}

static const uint32_t p10[10] = {
    1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
    10000u, 1000u, 100u, 10u, 1u
};

static void put_dec(uint32_t v)
{
    int i;
    int started = 0;
    uint32_t d;

    for (i = 0; i < 10; i = i + 1) {
        d = 0u;
        while (v >= p10[i]) {
            v = v - p10[i];
            d = d + 1u;
        }
        if (d != 0u || started || i == 9) {
            uart_putc((uint8_t)('0' + d));
            started = 1;
        }
    }
}

static uint32_t to_bcd(uint32_t v)
{
    uint32_t r = 0u;
    int i;
    uint32_t d;

    for (i = 2; i < 10; i = i + 1) {
        d = 0u;
        while (v >= p10[i]) {
            v = v - p10[i];
            d = d + 1u;
        }
        r = (r << 4) | d;
    }
    return r;
}

static uint32_t __attribute__((noinline)) sw_mul(uint32_t a, uint32_t b)
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

static void hw_start(uint32_t a, uint32_t b)
{
    MUL_A = a;
    MUL_B = b;
    while ((MUL_STAT & 1u) != 0u) {
    }
}

int main(void)
{
    uint32_t i, bad = 0u;
    uint32_t t0, t1, sw_cycles, hw_cycles;
    uint32_t sum_sw = 0u, sum_hw = 0u;
    uint32_t n, q, ip, fr;
    volatile uint32_t va = 0xDEADBEEFu;
    volatile uint32_t vb = 0xCAFEBABEu;

    pstr("HW multiplier (MMIO, DSP48) vs software shift-add\r\n");

    for (i = 0u; i < N_MULV; i = i + 1u) {
        hw_start(mv_a[i], mv_b[i]);
        if (MUL_LO != mv_lo[i] || MUL_HI != mv_hi[i] || sw_mul(mv_a[i], mv_b[i]) != mv_lo[i])
            bad = bad + 1u;
    }
    pstr("vectors: ");
    put_dec(N_MULV);
    pstr(bad == 0u ? " PASS\r\n" : " FAIL\r\n");

    t0 = CYCLE;
    for (i = 0u; i < BENCH_N; i = i + 1u)
        sum_sw = sum_sw + sw_mul(va + i, vb);
    t1 = CYCLE;
    sw_cycles = t1 - t0;

    t0 = CYCLE;
    for (i = 0u; i < BENCH_N; i = i + 1u) {
        hw_start(va + i, vb);
        sum_hw = sum_hw + MUL_LO;
    }
    t1 = CYCLE;
    hw_cycles = t1 - t0;

    if (sum_sw != sum_hw)
        bad = bad + 1u;

    pstr("SW cycles for 100 multiplies: ");
    put_dec(sw_cycles);
    pstr("\r\nHW cycles for 100 multiplies: ");
    put_dec(hw_cycles);
    pstr("\r\n");

    n = (sw_cycles << 3) + (sw_cycles << 1);
    q = 0u;
    while (n >= hw_cycles) {
        n = n - hw_cycles;
        q = q + 1u;
    }
    ip = 0u;
    fr = q;
    while (fr >= 10u) {
        fr = fr - 10u;
        ip = ip + 1u;
    }
    pstr("Speedup: ");
    put_dec(ip);
    uart_putc('.');
    put_dec(fr);
    pstr("x\r\n");

    SEG_DATA = to_bcd(q);
    SEG_DP   = 0x02u;

    if (bad == 0u) {
        pstr("ALL PASS\r\n");
        LED_REG = 0xAAAAu;
    } else {
        pstr("FAIL\r\n");
        LED_REG = 0x0001u;
    }

    while (1) {
    }
    return 0;
}
