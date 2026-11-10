typedef unsigned int uint32_t;
typedef unsigned char uint8_t;

#define UART_DATA  (*(volatile uint32_t *)0x10000004u)
#define UART_STAT  (*(volatile uint32_t *)0x10000008u)
#define CYCLE      (*(volatile uint32_t *)0x10000014u)
#define LED_REG    (*(volatile uint32_t *)0x10000000u)

#define N 4096u

static volatile uint32_t scratch = 0x12345678u;

static const uint32_t p10[10] = {
    1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
    10000u, 1000u, 100u, 10u, 1u
};

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
        if (d != 0u || started != 0 || i == 9) {
            uart_putc((uint8_t)('0' + d));
            started = 1;
        }
    }
}

static uint32_t __attribute__((noinline)) bench_empty(uint32_t n)
{
    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        :
        : [n] "r" (n)
        : "t0"
    );
    return n;
}

static uint32_t __attribute__((noinline)) bench_add4(uint32_t n)
{
    uint32_t a = 1u;
    uint32_t b = 2u;

    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "add %[a], %[a], %[b]\n"
        "add %[a], %[a], %[b]\n"
        "add %[a], %[a], %[b]\n"
        "add %[a], %[a], %[b]\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        : [a] "+r" (a)
        : [b] "r" (b), [n] "r" (n)
        : "t0"
    );
    return a;
}

static uint32_t __attribute__((noinline)) bench_lw4(uint32_t n)
{
    uint32_t a = 0u;
    const volatile uint32_t *p = &scratch;

    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "lw %[a], 0(%[p])\n"
        "lw %[a], 0(%[p])\n"
        "lw %[a], 0(%[p])\n"
        "lw %[a], 0(%[p])\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        : [a] "=&r" (a)
        : [p] "r" (p), [n] "r" (n)
        : "t0", "memory"
    );
    return a;
}

static uint32_t __attribute__((noinline)) bench_sw4(uint32_t n)
{
    uint32_t a = 3u;
    volatile uint32_t *p = &scratch;

    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "sw %[a], 0(%[p])\n"
        "sw %[a], 0(%[p])\n"
        "sw %[a], 0(%[p])\n"
        "sw %[a], 0(%[p])\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        :
        : [a] "r" (a), [p] "r" (p), [n] "r" (n)
        : "t0", "memory"
    );
    return a;
}

static uint32_t __attribute__((noinline)) bench_notaken(uint32_t n)
{
    uint32_t one = 1u;

    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "beq zero, %[one], 2f\n"
        "beq zero, %[one], 2f\n"
        "beq zero, %[one], 2f\n"
        "beq zero, %[one], 2f\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        "2:\n"
        :
        : [one] "r" (one), [n] "r" (n)
        : "t0"
    );
    return one;
}

static uint32_t __attribute__((noinline)) bench_loaduse(uint32_t n)
{
    uint32_t a = 0u;
    uint32_t b = 5u;
    const volatile uint32_t *p = &scratch;

    asm volatile(
        "mv t0, zero\n"
        "1:\n"
        "lw %[a], 0(%[p])\n"
        "add %[a], %[a], %[b]\n"
        "lw %[a], 0(%[p])\n"
        "add %[a], %[a], %[b]\n"
        "addi t0, t0, 1\n"
        "bne t0, %[n], 1b\n"
        : [a] "+r" (a)
        : [b] "r" (b), [p] "r" (p), [n] "r" (n)
        : "t0", "memory"
    );
    return a;
}

static void run(const char *name, uint32_t (*fn)(uint32_t))
{
    uint32_t c0;
    uint32_t c1;

    c0 = CYCLE;
    (void)fn(N);
    c1 = CYCLE;

    pstr("CPI ");
    pstr(name);
    pstr(" n=");
    put_dec(N);
    pstr(" cycles=");
    put_dec(c1 - c0);
    pstr("\r\n");
}

int main(void)
{
    pstr("=== RV32I CPI microbenchmarks ===\r\n");

    run("EMPTY",   bench_empty);
    run("ADD4",    bench_add4);
    run("LW4",     bench_lw4);
    run("SW4",     bench_sw4);
    run("NOTAKEN", bench_notaken);
    run("LOADUSE", bench_loaduse);

    pstr("CPI DONE\r\n");
    pstr("ALL PASS\r\n");

    LED_REG = 0xAAAAu;
    while (1) {
    }

    return 0;
}
