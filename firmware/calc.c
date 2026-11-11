/* Interactive calculator: type an angle in degrees (digits + Enter) over UART,
 * the board answers with cos and sin (Q16.16 CORDIC) on UART and the 8-digit
 * display; the display alternates cos / sin until the next key.
 * RX register 0x10000034: bit8 valid, bit9 overrun, bits[7:0] data; write = ack. */
#ifdef HOST
#include <stdint.h>
#include <stdio.h>
static uint32_t seg_data_v, seg_dp_v, led_v, cyc_v;
static void uart_putc(uint8_t c) { putchar(c); }
static int rx_poll(void)
{
    int c = getchar();
    return (c == EOF) ? -2 : c;
}
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
#define UART_RX   (*(volatile uint32_t *)0x10000034u)
#ifndef HOLD_CYCLES
#define HOLD_CYCLES 75000000u   /* 1 s per face at 75 MHz */
#endif
static void uart_putc(uint8_t c)
{
    while ((UART_STAT & 1u) != 0u) {
    }
    UART_DATA = (uint32_t)c;
}
/* returns -1 when nothing is waiting */
static int rx_poll(void)
{
    uint32_t v = UART_RX;
    if ((v & 0x100u) == 0u)
        return -1;
    UART_RX = 0u;               /* ack: clears valid + overrun */
    return (int)(v & 0xFFu);
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

/* same packing as mathdisp.c; say = 1 also prints the line on UART */
static void show(uint32_t fn, uint32_t ang, int32_t val, uint32_t say)
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

    if (say != 0u) {
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
}

int main(void)
{
    uint8_t  buf[3];
    uint32_t n = 0u;
    uint32_t ang = 0u, t0 = 0u, face = 0u, have = 0u;
    int32_t  c, s, k;
    uint32_t i;

    pstr("RV32I calculator. Type an angle (degrees) + Enter.\r\n> ");

    for (;;) {
        k = rx_poll();
#ifdef HOST
        if (k == -2)
            return 0;
#endif
        if (k < 0) {
            if (have != 0u && (CYCLE - t0) >= HOLD_CYCLES) {
                face = face ^ 1u;
                fx_cossin_deg(ang, &c, &s);
                if (face == 0u) show(0xCu, ang, c, 0u);
                else            show(0x5u, ang, s, 0u);
                t0 = CYCLE;
            }
            continue;
        }

        if (k >= '0' && k <= '9') {
            if (n < 3u) {
                buf[n] = (uint8_t)(k - '0');
                n = n + 1u;
                uart_putc((uint8_t)k);
            }
        } else if (k == 8 || k == 127) {
            if (n > 0u) {
                n = n - 1u;
                pstr("\b \b");
            }
        } else if (k == '\r' || k == '\n') {
            pstr("\r\n");
            if (n > 0u) {
                ang = 0u;
                for (i = 0u; i < n; i = i + 1u)
                    ang = (ang << 3) + (ang << 1) + buf[i];
                while (ang >= 360u)
                    ang = ang - 360u;
                fx_cossin_deg(ang, &c, &s);
                show(0xCu, ang, c, 1u);
                show(0x5u, ang, s, 1u);      /* display now shows sin */
                face = 1u;
                have = 1u;
                t0 = CYCLE;
                LED_REG = ang;
                n = 0u;
            }
            pstr("> ");
        }
    }
}
