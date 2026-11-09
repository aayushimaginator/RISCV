import re, sys
p = "firmware/selftest.c"
s = open(p).read()
if "do_lb" in s:
    print("already patched"); sys.exit(0)

helpers = r'''
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

'''
s = s.replace("static void delay(void)", helpers + "static void delay(void)", 1)

s, n1 = re.subn(r"\(uint32_t\)\(int8_t\)\(\(volatile int8_t \*\)&mem32\)\[(\d)\]",
                r"do_lb((volatile uint8_t *)&mem32 + \1)", s)
s, n2 = re.subn(r"\(uint32_t\)\(int16_t\)\(\(volatile int16_t \*\)&mem32\)\[(\d)\]",
                lambda m: "do_lh((volatile uint8_t *)&mem32 + %d)" % (2*int(m.group(1))), s)

n3 = 0
for a, b, fn in [("neg1","pos1","do_blt"),("pos1","neg1","do_blt")]:
    pat = r"if \(%s < %s\)\n\s+res = 1u;\n\s+else\n\s+res = 0u;" % (a, b)
    s, k = re.subn(pat, "res = %s(%s, %s);" % (fn, a, b), s); n3 += k
for a, b in [("pos1","neg1"),("neg1","pos1")]:
    pat = r"if \(%s >= %s\)\n\s+res = 1u;\n\s+else\n\s+res = 0u;" % (a, b)
    s, k = re.subn(pat, "res = do_bge(%s, %s);" % (a, b), s); n3 += k

s, n4 = re.subn(r"\(neg1 < 0\) \? 1u : 0u", "do_slti0(neg1)", s)
s, n5 = re.subn(r"\(umax < 1u\) \? 1u : 0u", "do_sltiu1(umax)", s)
print("lb", n1, "lh", n2, "branch", n3, "slti", n4, "sltiu", n5)
assert (n1, n2, n3, n4, n5) == (4, 2, 4, 1, 1), "unexpected match counts"
open(p, "w").write(s)
