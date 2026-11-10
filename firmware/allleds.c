typedef unsigned int uint32_t;
typedef unsigned char uint8_t;

#define LED_REG    (*(volatile uint32_t *)0x10000000u)
#define UART_DATA  (*(volatile uint32_t *)0x10000004u)
#define UART_STAT  (*(volatile uint32_t *)0x10000008u)

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

int main(void)
{
    pstr("ALL LEDS ON\r\n");
    LED_REG = 0xFFFFu;
    while (1) {
    }
    return 0;
}
