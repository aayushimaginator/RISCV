#!/usr/bin/env python3
"""
Independently recompute every EXP_* constant in firmware/selftest.c.

This script does not run the firmware.  It only checks that the known-answer
constants in the C source match Python-computed values.
"""

import re
import sys
import zlib

SRC = "firmware/selftest.c"
MASK = 0xFFFFFFFF


def u32(x):
    return x & MASK


def s32(x):
    x &= MASK
    if x >= 0x80000000:
        return x - 0x100000000
    return x


def parse_defines(text):
    defs = {}
    pat = re.compile(
        r"^\s*#\s*define\s+(EXP_[A-Za-z0-9_]+)\s+"
        r"([0-9]+|0[xX][0-9a-fA-F]+)\s*u?\s*$",
        re.M,
    )
    for m in pat.finditer(text):
        defs[m.group(1)] = int(m.group(2), 0)
    return defs


def expected_values():
    exp = {}

    # T01 CRC-32 of "123456789", reflected polynomial 0xEDB88320.
    exp["EXP_CRC32"] = zlib.crc32(b"123456789") & MASK

    # T02 Fibonacci.
    def fib_iter(n):
        a, b = 0, 1
        for _ in range(n):
            a, b = b, a + b
        return a

    def fib_rec(n):
        if n <= 1:
            return n
        return fib_rec(n - 1) + fib_rec(n - 2)

    exp["EXP_FIB20"] = fib_iter(20)
    exp["EXP_FIB15"] = fib_rec(15)

    # T03 Bubble sort result.
    arr = [5, 2, 9, 1, 5, 6, 0, 3]
    arr_sorted = sorted(arr)
    for i, v in enumerate(arr_sorted):
        exp[f"EXP_SORT{i}"] = v

    # T04 ALU.
    exp["EXP_ALU_ADD_OVERFLOW"]  = u32(0x7FFFFFFF + 1)
    exp["EXP_ALU_SUB_UNDERFLOW"] = u32(0 - 1)

    exp["EXP_ALU_SHL31"] = u32(1 << 31)
    exp["EXP_ALU_LSR31"] = u32(0x80000000 >> 31)
    exp["EXP_ALU_ASR31"] = u32(s32(0x80000000) >> 31)

    val = 0x12345678
    exp["EXP_ALU_SHL0"] = u32(val << 0)
    exp["EXP_ALU_LSR0"] = u32(val >> 0)
    exp["EXP_ALU_ASR0"] = u32(s32(0xDEADBEEF) >> 0)

    exp["EXP_ALU_SHL_VAR"] = u32(val << 4)
    exp["EXP_ALU_LSR_VAR"] = u32(val >> 4)
    exp["EXP_ALU_ASR_VAR"] = u32(s32(val) >> 4)

    m1 = 0xA5A5A5A5
    m2 = 0x0F0F0F0F
    exp["EXP_ALU_XOR"] = u32(m1 ^ m2)
    exp["EXP_ALU_OR"]  = u32(m1 | m2)
    exp["EXP_ALU_AND"] = u32(m1 & m2)

    # T05 Compares/branches.
    exp["EXP_CMP_SLT_NEG"]   = 1 if s32(0xFFFFFFFF) < 1 else 0
    exp["EXP_CMP_SLTU_MAX"]  = 1 if 0xFFFFFFFF < 1 else 0
    exp["EXP_CMP_SLTI_NEG"]  = 1 if s32(0xFFFFFFFF) < 0 else 0
    exp["EXP_CMP_SLTIU_MAX"] = 1 if 0xFFFFFFFF < 1 else 0

    exp["EXP_BR_BLT_TAKEN"]  = 1 if s32(0xFFFFFFFF) < 1 else 0
    exp["EXP_BR_BLT_NOT"]    = 1 if 1 < s32(0xFFFFFFFF) else 0
    exp["EXP_BR_BGE_TAKEN"]  = 1 if 1 >= s32(0xFFFFFFFF) else 0
    exp["EXP_BR_BGE_NOT"]    = 1 if s32(0xFFFFFFFF) >= 1 else 0

    exp["EXP_BR_BLTU_TAKEN"] = 1 if 1 < 0xFFFFFFFF else 0
    exp["EXP_BR_BLTU_NOT"]   = 1 if 0xFFFFFFFF < 1 else 0
    exp["EXP_BR_BGEU_TAKEN"] = 1 if 0xFFFFFFFF >= 1 else 0
    exp["EXP_BR_BGEU_NOT"]   = 1 if 1 >= 0xFFFFFFFF else 0

    # T06 Memory, little-endian.
    word = 0x80FF7F01
    b = [(word >> (8 * i)) & 0xFF for i in range(4)]

    def sign8(x):
        return x - 256 if x >= 128 else x

    def sign16(x):
        return x - 65536 if x >= 32768 else x

    exp["EXP_MEM_LB0"]  = u32(sign8(b[0]))
    exp["EXP_MEM_LB1"]  = u32(sign8(b[1]))
    exp["EXP_MEM_LB2"]  = u32(sign8(b[2]))
    exp["EXP_MEM_LB3"]  = u32(sign8(b[3]))

    exp["EXP_MEM_LBU0"] = b[0]
    exp["EXP_MEM_LBU1"] = b[1]
    exp["EXP_MEM_LBU2"] = b[2]
    exp["EXP_MEM_LBU3"] = b[3]

    h0 = b[0] | (b[1] << 8)
    h2 = b[2] | (b[3] << 8)

    exp["EXP_MEM_LH0"]  = u32(sign16(h0))
    exp["EXP_MEM_LHU0"] = h0
    exp["EXP_MEM_LH2"]  = u32(sign16(h2))
    exp["EXP_MEM_LHU2"] = h2

    # After sb byte0=0xAA and sh halfword offset2=0x1234:
    # byte3=0x12, byte2=0x34, byte1=0x7F, byte0=0xAA
    exp["EXP_MEM_PARTIAL_WORD"] = u32((0x1234 << 16) | (b[1] << 8) | 0xAA)

    # T07 Function pointers.
    exp["EXP_FP0"] = 0x11111111
    exp["EXP_FP1"] = 0x22222222
    exp["EXP_FP2"] = 0x33333333
    exp["EXP_FP3"] = 0x44444444

    return exp


def main():
    try:
        with open(SRC, "r") as f:
            src = f.read()
    except OSError as e:
        print(f"check_selftest: cannot read {SRC}: {e}")
        return 1

    defs = parse_defines(src)
    exp = expected_values()

    ok = True

    for name, py_val in sorted(exp.items()):
        if name not in defs:
            print(f"MISSING {name}: not found in {SRC}")
            ok = False
            continue

        c_val = defs[name]
        if c_val != py_val:
            print(f"MISMATCH {name}: c={c_val:#010x} python={py_val:#010x}")
            ok = False

    # Optional: catch typos in extra EXP_* macros.
    for name in sorted(defs.keys()):
        if name not in exp:
            print(f"UNKNOWN {name}: present in {SRC}, not in Python expected set")
            ok = False

    if not ok:
        print("check_selftest: FAIL")
        return 1

    print("check_selftest: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
