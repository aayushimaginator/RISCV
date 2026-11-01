#ifndef DELAY_N
#define DELAY_N 100000
#endif

#define LED_REG        (*(volatile unsigned int *)0x10000000u)
#define UART_TX        (*(volatile unsigned int *)0x10000004u)
#define UART_STATUS    (*(volatile unsigned int *)0x10000008u)

#define UART_BUSY_MASK 0x00000001u

static void delay(unsigned int n)
{
    volatile unsigned int i;

    for (i = 0; i < n; i = i + 1) {
        __asm__ volatile ("nop");
    }
}

static void uart_putc(char c)
{
    while (UART_STATUS & UART_BUSY_MASK) {
        /* busy wait */
    }

    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s);
        s = s + 1;
    }
}

int main(void)
{
    const char *s = "Hello, RV32I!\r\n";

    unsigned int mask = 0x00000001u;
    int dir = 1;

    uart_puts(s);

    while (1) {
        LED_REG = mask;

        delay(DELAY_N);

        if (dir) {
            if (mask == 0x00008000u) {
                dir = 0;
            }
            else {
                mask = mask << 1;
            }
        }
        else {
            if (mask == 0x00000001u) {
                dir = 1;
            }
            else {
                mask = mask >> 1;
            }
        }
    }

    return 0;
}
