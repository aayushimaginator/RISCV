typedef unsigned int      uint32_t;
typedef unsigned short    uint16_t;
typedef short             int16_t;
typedef unsigned char     uint8_t;
typedef signed char       int8_t;

#define LED_REG    (*(volatile uint32_t *)0x10000000u)
#define UART_DATA  (*(volatile uint32_t *)0x10000004u)
#define UART_STAT  (*(volatile uint32_t *)0x10000008u)

#define TEST_BEGIN 0x2000u
#define TEST_END   0x3F00u

static const uint32_t ram16_marker __attribute__((section(".rodata"))) = 0xC0DE1616u;

static inline __attribute__((always_inline)) void uart_putc(uint8_t c)
{
    while ((UART_STAT & 1u) != 0u) {
    }
    UART_DATA = (uint32_t)c;
}

static inline __attribute__((always_inline)) void pstr(const char *s)
{
    while (*s != 0) {
        uart_putc((uint8_t)*s);
        s = s + 1;
    }
}

static inline __attribute__((always_inline)) void put_hex32(uint32_t x)
{
    uint32_t shift;
    uint32_t nib;

    shift = 28u;

    while (1) {
        nib = (x >> shift) & 0xFu;

        if (nib < 10u)
            uart_putc((uint8_t)('0' + nib));
        else
            uart_putc((uint8_t)('A' + (nib - 10u)));

        if (shift == 0u)
            break;

        shift = shift - 4u;
    }
}

static inline __attribute__((always_inline)) void fail(uint32_t addr)
{
    pstr("RAM16 FAIL ");
    put_hex32(addr);
    pstr("\r\n");
    LED_REG = 0x0001u;

    while (1) {
    }
}

static inline __attribute__((always_inline)) uint32_t pattern_for(uint32_t addr)
{
    return (addr << 1) ^ (addr >> 3) ^ 0xA5A5A5A5u;
}

static inline __attribute__((always_inline)) void test_lane(uint32_t base)
{
    volatile uint32_t *w;
    volatile uint8_t  *b;
    volatile uint16_t *h;

    w = (volatile uint32_t *)base;
    b = (volatile uint8_t  *)base;
    h = (volatile uint16_t *)base;

    *w = 0x80FF7F01u;

    if ((uint32_t)(int8_t)b[0] != 0x00000001u)
        fail(base + 0u);

    if ((uint32_t)(int8_t)b[1] != 0x0000007Fu)
        fail(base + 1u);

    if ((uint32_t)(int8_t)b[2] != 0xFFFFFFFFu)
        fail(base + 2u);

    if ((uint32_t)(int8_t)b[3] != 0xFFFFFF80u)
        fail(base + 3u);

    if ((uint32_t)b[0] != 0x00000001u)
        fail(base + 0u);

    if ((uint32_t)b[1] != 0x0000007Fu)
        fail(base + 1u);

    if ((uint32_t)b[2] != 0x000000FFu)
        fail(base + 2u);

    if ((uint32_t)b[3] != 0x00000080u)
        fail(base + 3u);

    if ((uint32_t)(int16_t)h[0] != 0x00007F01u)
        fail(base + 0u);

    if ((uint32_t)h[0] != 0x00007F01u)
        fail(base + 0u);

    if ((uint32_t)(int16_t)h[1] != 0xFFFF80FFu)
        fail(base + 2u);

    if ((uint32_t)h[1] != 0x000080FFu)
        fail(base + 2u);

    b[0] = 0xAAu;
    h[1] = 0x1234u;

    if (*w != 0x12347FAAu)
        fail(base + 4u);
}

int main(void)
{
    uint32_t addr;
    uint32_t pat;
    uint32_t marker_addr;

    pstr("=== RV32I 16K RAM test ===\r\n");

    for (addr = TEST_BEGIN; addr < TEST_END; addr = addr + 4u) {
        pat = pattern_for(addr);
        *(volatile uint32_t *)addr = pat;
    }

    for (addr = TEST_BEGIN; addr < TEST_END; addr = addr + 4u) {
        pat = pattern_for(addr);
        if (*(volatile uint32_t *)addr != pat)
            fail(addr);
    }

    test_lane(0x2000u);
    test_lane(0x3000u);

    marker_addr = (uint32_t)&ram16_marker;

    if (*(volatile uint32_t *)marker_addr != 0xC0DE1616u)
        fail(0u);

    pstr("RAM16 PASS\r\n");
    LED_REG = 0xAAAAu;
    pstr("ALL PASS\r\n");

    while (1) {
    }

    return 0;
}
