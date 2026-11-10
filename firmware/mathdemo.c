#ifdef HOST
#include <stdint.h>
#include <stdio.h>
static void uart_putc(uint8_t c) { putchar(c); }
#define LED_SET(v) ((void)(v))
#else
typedef unsigned int  uint32_t;
typedef int           int32_t;
typedef unsigned char uint8_t;
#define LED_REG   (*(volatile uint32_t *)0x10000000u)
#define UART_DATA (*(volatile uint32_t *)0x10000004u)
#define UART_STAT (*(volatile uint32_t *)0x10000008u)
#define LED_SET(v) (LED_REG = (v))
static void uart_putc(uint8_t c)
{
    while ((UART_STAT & 1u) != 0u) {
    }
    UART_DATA = (uint32_t)c;
}
#endif

#include "fxmath.h"
#include "mathexp.h"

#define TOL 8

static void pstr(const char *s)
{
    while (*s != 0) {
        uart_putc((uint8_t)*s);
        s = s + 1;
    }
}

static void put_dec(uint32_t v)
{
    static const uint32_t p10[10] = {
        1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
        10000u, 1000u, 100u, 10u, 1u
    };
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

static void put_q16(int32_t v)
{
    uint32_t a, ip, fr, k, d;
    static const uint32_t p[4] = {1000u, 100u, 10u, 1u};

    a = (v < 0) ? (uint32_t)(-v) : (uint32_t)v;
    ip = a >> 16;
    fr = (fx_umul(a & 0xFFFFu, 10000u) + 32768u) >> 16;
    if (fr >= 10000u) {
        fr = fr - 10000u;
        ip = ip + 1u;
    }
    if (v < 0 && (ip != 0u || fr != 0u))
        uart_putc('-');
    put_dec(ip);
    uart_putc('.');
    for (k = 0u; k < 4u; k = k + 1u) {
        d = 0u;
        while (fr >= p[k]) {
            fr = fr - p[k];
            d = d + 1u;
        }
        uart_putc((uint8_t)('0' + d));
    }
}

static int near(int32_t got, int32_t exp)
{
    int32_t d = got - exp;
    if (d < 0)
        d = -d;
    return d <= TOL;
}

int main(void)
{
    uint32_t i;
    uint32_t bad = 0u;
    int32_t c, s, l;

    pstr("RV32I fixed-point math demo (CORDIC, no multiplier)\r\n");

    for (i = 0u; i < N_DEG; i = i + 1u) {
        fx_cossin_deg(exp_deg[i], &c, &s);
        pstr("deg ");
        put_dec(exp_deg[i]);
        pstr("  cos ");
        put_q16(c);
        pstr("  sin ");
        put_q16(s);
        if (near(c, exp_cos[i]) && near(s, exp_sin[i])) {
            pstr("  PASS\r\n");
        } else {
            pstr("  FAIL\r\n");
            bad = bad + 1u;
        }
    }

    for (i = 0u; i < N_X; i = i + 1u) {
        l = (int32_t)fx_ln(exp_x[i]);
        pstr("ln ");
        put_dec(exp_x[i]);
        pstr("  = ");
        put_q16(l);
        if (near(l, exp_ln[i])) {
            pstr("  PASS\r\n");
        } else {
            pstr("  FAIL\r\n");
            bad = bad + 1u;
        }
    }

    if (bad == 0u) {
        pstr("ALL PASS\r\n");
        LED_SET(0xAAAAu);
    } else {
        pstr("FAIL\r\n");
        LED_SET(0x0001u);
    }
#ifdef HOST
    return (int)bad;
#else
    while (1) {
    }
#endif
}
