#ifdef HOST
#include <stdint.h>
#include <stdio.h>
static uint32_t seg_data_v, seg_dp_v, led_v, cyc_v;
static void uart_putc(uint8_t c) { putchar(c); }
#define SEG_DATA seg_data_v
#define SEG_DP   seg_dp_v
#define LED_REG  led_v
#define CYCLE    (cyc_v += 1000u)
#define HOLD_CYCLES 3000u
#else
typedef unsigned int  uint32_t;
typedef int           int32_t;
typedef unsigned char uint8_t;
#define LED_REG   (*(volatile uint32_t *)0x10000000u)
#define UART_DATA (*(volatile uint32_t *)0x10000004u)
#define UART_STAT (*(volatile uint32_t *)0x10000008u)
#define SEG_DATA  (*(volatile uint32_t *)0x1000000Cu)
#define SEG_DP    (*(volatile uint32_t *)0x10000010u)
#define CYCLE     (*(volatile uint32_t *)0x10000014u)
#ifndef HOLD_CYCLES
#define HOLD_CYCLES 40000000u
#endif
static void uart_putc(uint8_t c)
{
    while ((UART_STAT & 1u) != 0u) {
    }
    UART_DATA = (uint32_t)c;
}
#endif

#pragma GCC diagnostic ignored "-Wunused-function"
#include "fxmath.h"

static void pstr(const char *s)
{
    while (*s != 0) {
        uart_putc((uint8_t)*s);
        s = s + 1;
    }
}

static void put3(uint32_t v)
{
    uint32_t h = 0u, t = 0u;
    while (v >= 100u) { v = v - 100u; h = h + 1u; }
    while (v >= 10u)  { v = v - 10u;  t = t + 1u; }
    uart_putc((uint8_t)('0' + h));
    uart_putc((uint8_t)('0' + t));
    uart_putc((uint8_t)('0' + v));
}

static void wait_cycles(uint32_t n)
{
    uint32_t t0 = CYCLE;
    while ((CYCLE - t0) < n) {
    }
}

static void show(uint32_t fn, uint32_t ang, int32_t val)
{
    uint32_t neg = (val < 0) ? 1u : 0u;
    uint32_t mag = neg ? (uint32_t)(-val) : (uint32_t)val;
    uint32_t v   = (fx_umul(mag, 1000u) + 32768u) >> 16;
    uint32_t ip = 0u, fh = 0u, ft = 0u;
    uint32_t ah = 0u, at = 0u, a = ang;

    if (v == 0u)
        neg = 0u;
    if (v >= 1000u) { v = v - 1000u; ip = 1u; }
    while (v >= 100u) { v = v - 100u; fh = fh + 1u; }
    while (v >= 10u)  { v = v - 10u;  ft = ft + 1u; }
    while (a >= 100u) { a = a - 100u; ah = ah + 1u; }
    while (a >= 10u)  { a = a - 10u;  at = at + 1u; }

    SEG_DATA = (fn << 28) | (ah << 24) | (at << 20) | (a << 16)
             | (ip << 12) | (fh << 8) | (ft << 4) | v;
    SEG_DP = 0x08u | (neg ? 0x10u : 0u);

    pstr(fn == 0xCu ? "cos " : "sin ");
    put3(ang);
    pstr(neg ? " = -" : " = +");
    uart_putc((uint8_t)('0' + ip));
    uart_putc('.');
    uart_putc((uint8_t)('0' + fh));
    uart_putc((uint8_t)('0' + ft));
    uart_putc((uint8_t)('0' + v));
    pstr("\r\n");
#ifdef HOST
    printf("SCR %u %u %08x %02x\n", fn, ang, seg_data_v, seg_dp_v);
#endif
}

int main(void)
{
    uint32_t ang, idx;
    int32_t c, s;

    pstr("RV32I calculator readout: cos and sin from CORDIC\r\n");

    for (;;) {
        idx = 0u;
        for (ang = 0u; ang < 360u; ang = ang + 15u) {
            fx_cossin_deg(ang, &c, &s);
            show(0xCu, ang, c);
            LED_REG = 1u << (idx & 15u);
            wait_cycles(HOLD_CYCLES);
            show(0x5u, ang, s);
            wait_cycles(HOLD_CYCLES);
            idx = idx + 1u;
        }
#ifdef HOST
        return 0;
#endif
    }
}
