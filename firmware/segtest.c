typedef unsigned int uint32_t;

#ifndef SEG_VALUE
#define SEG_VALUE 0xCBF43926u
#endif

#define LED_REG   (*(volatile uint32_t *)0x10000000u)
#define SEG_DATA  (*(volatile uint32_t *)0x1000000Cu)
#define SEG_DP    (*(volatile uint32_t *)0x10000010u)

int main(void)
{
    SEG_DATA = SEG_VALUE;
    SEG_DP   = 0x10u;
    LED_REG  = 0xAAAAu;

    if (SEG_DATA != SEG_VALUE)
        LED_REG = 0x0001u;

    while (1) {
    }
    return 0;
}
