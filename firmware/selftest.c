typedef unsigned int  uint32_t;
typedef int           int32_t;
typedef unsigned short uint16_t;
typedef short          int16_t;
typedef unsigned char  uint8_t;
typedef signed char    int8_t;

/*
 * Match these to the existing SoC/memory map if your main.c differs.
 * Do not change RTL.
 */
#define LED_REG    (*(volatile uint32_t *)0x10000000u)
#define UART_DATA  (*(volatile uint32_t *)0x10000004u)
#define UART_STAT  (*(volatile uint32_t *)0x10000008u)

/*
 * Conservative byte spacing.  This avoids depending on a UART busy/status
 * register.  It is slow enough to be safe on 50/75 MHz, but still small code.
 */
#define DELAY_COUNT 4000u

/* -------------------------------------------------------------------------- */
/* Known-answer constants.  tools/check_selftest.py recomputes these.         */
/* -------------------------------------------------------------------------- */

#define EXP_CRC32                 0xCBF43926u

#define EXP_FIB20                 6765u
#define EXP_FIB15                 610u

#define EXP_SORT0                 0x00000000u
#define EXP_SORT1                 0x00000001u
#define EXP_SORT2                 0x00000002u
#define EXP_SORT3                 0x00000003u
#define EXP_SORT4                 0x00000005u
#define EXP_SORT5                 0x00000005u
#define EXP_SORT6                 0x00000006u
#define EXP_SORT7                 0x00000009u

#define EXP_ALU_ADD_OVERFLOW      0x80000000u
#define EXP_ALU_SUB_UNDERFLOW     0xFFFFFFFFu

#define EXP_ALU_SHL31             0x80000000u
#define EXP_ALU_LSR31             0x00000001u
#define EXP_ALU_ASR31             0xFFFFFFFFu

#define EXP_ALU_SHL0              0x12345678u
#define EXP_ALU_LSR0              0x12345678u
#define EXP_ALU_ASR0              0xDEADBEEFu

#define EXP_ALU_SHL_VAR           0x23456780u
#define EXP_ALU_LSR_VAR           0x01234567u
#define EXP_ALU_ASR_VAR           0x01234567u

#define EXP_ALU_XOR               0xAAAAAAAAu
#define EXP_ALU_OR                0xAFAFAFAFu
#define EXP_ALU_AND               0x05050505u

#define EXP_CMP_SLT_NEG           0x00000001u
#define EXP_CMP_SLTU_MAX          0x00000000u
#define EXP_CMP_SLTI_NEG          0x00000001u
#define EXP_CMP_SLTIU_MAX         0x00000000u

#define EXP_BR_BLT_TAKEN          0x00000001u
#define EXP_BR_BLT_NOT            0x00000000u
#define EXP_BR_BGE_TAKEN          0x00000001u
#define EXP_BR_BGE_NOT            0x00000000u
#define EXP_BR_BLTU_TAKEN         0x00000001u
#define EXP_BR_BLTU_NOT           0x00000000u
#define EXP_BR_BGEU_TAKEN         0x00000001u
#define EXP_BR_BGEU_NOT           0x00000000u

#define EXP_MEM_LB0               0x00000001u
#define EXP_MEM_LB1               0x0000007Fu
#define EXP_MEM_LB2               0xFFFFFFFFu
#define EXP_MEM_LB3               0xFFFFFF80u

#define EXP_MEM_LBU0              0x00000001u
#define EXP_MEM_LBU1              0x0000007Fu
#define EXP_MEM_LBU2              0x000000FFu
#define EXP_MEM_LBU3              0x00000080u

#define EXP_MEM_LH0               0x00007F01u
#define EXP_MEM_LHU0              0x00007F01u
#define EXP_MEM_LH2               0xFFFF80FFu
#define EXP_MEM_LHU2              0x000080FFu

#define EXP_MEM_PARTIAL_WORD      0x12347FAAu

#define EXP_FP0                   0x11111111u
#define EXP_FP1                   0x22222222u
#define EXP_FP2                   0x33333333u
#define EXP_FP3                   0x44444444u

/* -------------------------------------------------------------------------- */
/* Tiny runtime support.  No libc, no libgcc, no mul/div/rem.                 */
/* -------------------------------------------------------------------------- */

static volatile uint32_t fails;
static volatile uint32_t mem32;

static volatile uint8_t crc_msg[9] = {
    (uint8_t)'1', (uint8_t)'2', (uint8_t)'3', (uint8_t)'4',
    (uint8_t)'5', (uint8_t)'6', (uint8_t)'7', (uint8_t)'8',
    (uint8_t)'9'
};

static volatile uint32_t sort_arr[8] = {
    5u, 2u, 9u, 1u, 5u, 6u, 0u, 3u
};


static inline uint32_t do_lb(const volatile uint8_t *p)
{
    uint32_t r;
    __asm__ volatile ("lb %0, 0(%1)" : "=r"(r) : "r"(p) : "memory");
    return r;
}

static inline uint32_t do_lh(const volatile uint8_t *p)
{
    uint32_t r;
    __asm__ volatile ("lh %0, 0(%1)" : "=r"(r) : "r"(p) : "memory");
    return r;
}

static inline uint32_t do_blt(int32_t a, int32_t b)
{
    uint32_t r;
    __asm__ volatile ("li %0, 1\n\tblt %1, %2, 1f\n\tli %0, 0\n1:"
                      : "=&r"(r) : "r"(a), "r"(b));
    return r;
}

static inline uint32_t do_bge(int32_t a, int32_t b)
{
    uint32_t r;
    __asm__ volatile ("li %0, 1\n\tbge %1, %2, 1f\n\tli %0, 0\n1:"
                      : "=&r"(r) : "r"(a), "r"(b));
    return r;
}

static inline uint32_t do_slti0(int32_t a)
{
    uint32_t r;
    __asm__ volatile ("slti %0, %1, 0" : "=r"(r) : "r"(a));
    return r;
}

static inline uint32_t do_sltiu1(uint32_t a)
{
    uint32_t r;
    __asm__ volatile ("sltiu %0, %1, 1" : "=r"(r) : "r"(a));
    return r;
}

static void delay(void)
{
    volatile uint32_t i;
    for (i = 0u; i < DELAY_COUNT; i = i + 1u) {
        /* empty volatile loop */
    }
}

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

static void put_hex32(uint32_t x)
{
    uint32_t shift;
    shift = 28u;

    while (1) {
        uint32_t nib;
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

static void check(const char *name, uint32_t got, uint32_t exp)
{
    pstr(name);
    pstr(" ");

    if (got == exp) {
        pstr("PASS\r\n");
    } else {
        pstr("FAIL got=");
        put_hex32(got);
        pstr(" exp=");
        put_hex32(exp);
        pstr("\r\n");
        fails = fails + 1u;
    }
}

/* -------------------------------------------------------------------------- */
/* T01: CRC-32, bitwise, poly 0xEDB88320.                                     */
/* -------------------------------------------------------------------------- */

static uint32_t crc32_bits(const volatile uint8_t *p, uint32_t len)
{
    uint32_t crc;
    uint32_t i;
    uint32_t b;

    crc = 0xFFFFFFFFu;

    for (i = 0u; i < len; i = i + 1u) {
        crc = crc ^ (uint32_t)p[i];

        for (b = 0u; b < 8u; b = b + 1u) {
            if ((crc & 1u) != 0u)
                crc = (crc >> 1u) ^ 0xEDB88320u;
            else
                crc = crc >> 1u;
        }
    }

    return crc ^ 0xFFFFFFFFu;
}

/* -------------------------------------------------------------------------- */
/* T02: Fibonacci, iterative and recursive.                                   */
/* -------------------------------------------------------------------------- */

static uint32_t fib_iter(uint32_t n)
{
    uint32_t a;
    uint32_t b;
    uint32_t t;
    uint32_t i;

    a = 0u;
    b = 1u;

    for (i = 0u; i < n; i = i + 1u) {
        t = a + b;
        a = b;
        b = t;
    }

    return a;
}

static uint32_t __attribute__((noinline)) fib_rec(uint32_t n)
{
    if (n <= 1u)
        return n;

    return fib_rec(n - 1u) + fib_rec(n - 2u);
}

/* -------------------------------------------------------------------------- */
/* T03: Bubble sort.                                                          */
/* -------------------------------------------------------------------------- */

static void bubble_sort(void)
{
    uint32_t i;
    uint32_t j;
    uint32_t t;

    for (i = 0u; i < 8u; i = i + 1u) {
        for (j = 0u; j < (8u - i - 1u); j = j + 1u) {
            if (sort_arr[j] > sort_arr[j + 1u]) {
                t = sort_arr[j];
                sort_arr[j] = sort_arr[j + 1u];
                sort_arr[j + 1u] = t;
            }
        }
    }
}

/* -------------------------------------------------------------------------- */
/* T07: Function-pointer table.                                               */
/* -------------------------------------------------------------------------- */

static uint32_t __attribute__((noinline)) fp0(void) { return 0x11111111u; }
static uint32_t __attribute__((noinline)) fp1(void) { return 0x22222222u; }
static uint32_t __attribute__((noinline)) fp2(void) { return 0x33333333u; }
static uint32_t __attribute__((noinline)) fp3(void) { return 0x44444444u; }

typedef uint32_t (*fn_t)(void);

static volatile fn_t fptr[4] = {
    fp0,
    fp1,
    fp2,
    fp3
};

/* -------------------------------------------------------------------------- */
/* Main self-test.                                                            */
/* -------------------------------------------------------------------------- */

int main(void)
{
    uint32_t got;
    uint32_t res;

    volatile uint32_t a_pos_max;
    volatile uint32_t one;
    volatile uint32_t zero;

    volatile uint32_t high_bit;
    volatile uint32_t val;
    volatile int32_t  sval_neg;
    volatile int32_t  sval_pos;

    volatile uint32_t sh0;
    volatile uint32_t sh4;
    volatile uint32_t sh31;

    volatile uint32_t m1;
    volatile uint32_t m2;

    volatile int32_t  neg1;
    volatile int32_t  pos1;
    volatile uint32_t umax;
    volatile uint32_t uone;

    fails = 0u;
    mem32 = 0u;


    /* ---------------------------------------------------------------------- */
    /* T01 CRC-32                                                             */
    /* ---------------------------------------------------------------------- */
    got = crc32_bits(crc_msg, 9u);
    check("T01 CRC32", got, EXP_CRC32);

    /* ---------------------------------------------------------------------- */
    /* T02 Fibonacci                                                          */
    /* ---------------------------------------------------------------------- */
    got = fib_iter(20u);
    check("T02 FIB20", got, EXP_FIB20);

    got = fib_rec(15u);
    check("T02 FIB15", got, EXP_FIB15);

    /* ---------------------------------------------------------------------- */
    /* T03 Bubble sort                                                        */
    /* ---------------------------------------------------------------------- */
    bubble_sort();

    check("T03 SORT0", sort_arr[0], EXP_SORT0);
    check("T03 SORT1", sort_arr[1], EXP_SORT1);
    check("T03 SORT2", sort_arr[2], EXP_SORT2);
    check("T03 SORT3", sort_arr[3], EXP_SORT3);
    check("T03 SORT4", sort_arr[4], EXP_SORT4);
    check("T03 SORT5", sort_arr[5], EXP_SORT5);
    check("T03 SORT6", sort_arr[6], EXP_SORT6);
    check("T03 SORT7", sort_arr[7], EXP_SORT7);

    /* ---------------------------------------------------------------------- */
    /* T04 ALU / shifts                                                       */
    /* ---------------------------------------------------------------------- */
    a_pos_max = 0x7FFFFFFFu;
    one       = 1u;
    zero      = 0u;

    got = a_pos_max + one;
    check("T04 ADD_OVF", got, EXP_ALU_ADD_OVERFLOW);

    got = zero - one;
    check("T04 SUB_UNDF", got, EXP_ALU_SUB_UNDERFLOW);

    high_bit = 0x80000000u;
    val      = 0x12345678u;
    sval_neg = (int32_t)0x80000000u;
    sval_pos = (int32_t)0x12345678u;

    sh0  = 0u;
    sh4  = 4u;
    sh31 = 31u;

    got = one << sh31;
    check("T04 SHL31", got, EXP_ALU_SHL31);

    got = high_bit >> sh31;
    check("T04 LSR31", got, EXP_ALU_LSR31);

    got = (uint32_t)(sval_neg >> sh31);
    check("T04 ASR31", got, EXP_ALU_ASR31);

    got = val << sh0;
    check("T04 SHL0", got, EXP_ALU_SHL0);

    got = val >> sh0;
    check("T04 LSR0", got, EXP_ALU_LSR0);

    got = (uint32_t)((int32_t)0xDEADBEEFu >> sh0);
    check("T04 ASR0", got, EXP_ALU_ASR0);

    got = val << sh4;
    check("T04 SHL_VAR", got, EXP_ALU_SHL_VAR);

    got = val >> sh4;
    check("T04 LSR_VAR", got, EXP_ALU_LSR_VAR);

    got = (uint32_t)(sval_pos >> 4);
    check("T04 ASR_VAR", got, EXP_ALU_ASR_VAR);

    m1 = 0xA5A5A5A5u;
    m2 = 0x0F0F0F0Fu;

    got = m1 ^ m2;
    check("T04 XOR", got, EXP_ALU_XOR);

    got = m1 | m2;
    check("T04 OR", got, EXP_ALU_OR);

    got = m1 & m2;
    check("T04 AND", got, EXP_ALU_AND);

    /* ---------------------------------------------------------------------- */
    /* T05 Compares and branches                                              */
    /* ---------------------------------------------------------------------- */
    neg1 = -1;
    pos1 = 1;
    umax = 0xFFFFFFFFu;
    uone = 1u;

    got = (neg1 < pos1) ? 1u : 0u;
    check("T05 SLT_NEG", got, EXP_CMP_SLT_NEG);

    got = (umax < uone) ? 1u : 0u;
    check("T05 SLTU_MAX", got, EXP_CMP_SLTU_MAX);

    got = do_slti0(neg1);
    check("T05 SLTI_NEG", got, EXP_CMP_SLTI_NEG);

    got = do_sltiu1(umax);
    check("T05 SLTIU_MAX", got, EXP_CMP_SLTIU_MAX);

    res = do_blt(neg1, pos1);
    check("T05 BLT_TAKEN", res, EXP_BR_BLT_TAKEN);

    res = do_blt(pos1, neg1);
    check("T05 BLT_NOT", res, EXP_BR_BLT_NOT);

    res = do_bge(pos1, neg1);
    check("T05 BGE_TAKEN", res, EXP_BR_BGE_TAKEN);

    res = do_bge(neg1, pos1);
    check("T05 BGE_NOT", res, EXP_BR_BGE_NOT);

    if (uone < umax)
        res = 1u;
    else
        res = 0u;
    check("T05 BLTU_TAKEN", res, EXP_BR_BLTU_TAKEN);

    if (umax < uone)
        res = 1u;
    else
        res = 0u;
    check("T05 BLTU_NOT", res, EXP_BR_BLTU_NOT);

    if (umax >= uone)
        res = 1u;
    else
        res = 0u;
    check("T05 BGEU_TAKEN", res, EXP_BR_BGEU_TAKEN);

    if (uone >= umax)
        res = 1u;
    else
        res = 0u;
    check("T05 BGEU_NOT", res, EXP_BR_BGEU_NOT);

    /* ---------------------------------------------------------------------- */
    /* T06 Memory: word, byte, half, partial writes                           */
    /* ---------------------------------------------------------------------- */
    mem32 = 0x80FF7F01u;

    got = do_lb((volatile uint8_t *)&mem32 + 0);
    check("T06 LB0", got, EXP_MEM_LB0);

    got = do_lb((volatile uint8_t *)&mem32 + 1);
    check("T06 LB1", got, EXP_MEM_LB1);

    got = do_lb((volatile uint8_t *)&mem32 + 2);
    check("T06 LB2", got, EXP_MEM_LB2);

    got = do_lb((volatile uint8_t *)&mem32 + 3);
    check("T06 LB3", got, EXP_MEM_LB3);

    got = (uint32_t)((volatile uint8_t *)&mem32)[0];
    check("T06 LBU0", got, EXP_MEM_LBU0);

    got = (uint32_t)((volatile uint8_t *)&mem32)[1];
    check("T06 LBU1", got, EXP_MEM_LBU1);

    got = (uint32_t)((volatile uint8_t *)&mem32)[2];
    check("T06 LBU2", got, EXP_MEM_LBU2);

    got = (uint32_t)((volatile uint8_t *)&mem32)[3];
    check("T06 LBU3", got, EXP_MEM_LBU3);

    got = do_lh((volatile uint8_t *)&mem32 + 0);
    check("T06 LH0", got, EXP_MEM_LH0);

    got = (uint32_t)((volatile uint16_t *)&mem32)[0];
    check("T06 LHU0", got, EXP_MEM_LHU0);

    got = do_lh((volatile uint8_t *)&mem32 + 2);
    check("T06 LH2", got, EXP_MEM_LH2);

    got = (uint32_t)((volatile uint16_t *)&mem32)[1];
    check("T06 LHU2", got, EXP_MEM_LHU2);

    ((volatile uint8_t *)&mem32)[0] = 0xAAu;
    ((volatile uint16_t *)&mem32)[1] = 0x1234u;

    got = mem32;
    check("T06 PARTIAL_WORD", got, EXP_MEM_PARTIAL_WORD);

    /* ---------------------------------------------------------------------- */
    /* T07 Function pointers                                                  */
    /* ---------------------------------------------------------------------- */
    got = fptr[0]();
    check("T07 FP0", got, EXP_FP0);

    got = fptr[1]();
    check("T07 FP1", got, EXP_FP1);

    got = fptr[2]();
    check("T07 FP2", got, EXP_FP2);

    got = fptr[3]();
    check("T07 FP3", got, EXP_FP3);

    /* ---------------------------------------------------------------------- */
    /* Final result                                                           */
    /* ---------------------------------------------------------------------- */
    if (fails == 0u) {
        pstr("ALL PASS\r\n");
        LED_REG = 0xAAAAu;
    } else {
        pstr("FAILED ");
        put_hex32(fails);
        pstr("\r\n");
        LED_REG = 0x0001u;
    }

    while (1) {
        delay();
    }

    return 0;
}
