#!/usr/bin/env python3
"""Random terminating RV32I program. usage: gen_random_prog.py <seed>
Reserved: x31 = scratch base 0x1000, x30 = loop counter, x29 = jalr temp."""
import random, sys

rnd = random.Random(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
DST = list(range(1, 29))
SRC = list(range(0, 29))
out = []
cnt = [0]

def e(s):
    out.append("    " + s)

def newlab():
    cnt[0] += 1
    return "L%d" % cnt[0]

def dst():
    return 0 if rnd.random() < 0.03 else rnd.choice(DST)

def src():
    return rnd.choice(SRC)

def val32():
    r = rnd.random()
    if r < 0.15:
        v = rnd.choice([0, 1, 2, 31, 32, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF,
                        0xFFFFFFFE, 0x55555555, 0xAAAAAAAA, 0xFFFF, 0xFFFF0000])
    elif r < 0.3:
        v = rnd.randrange(-64, 64) & 0xFFFFFFFF
    else:
        v = rnd.getrandbits(32)
    return v - (1 << 32) if v >= (1 << 31) else v

def imm12():
    if rnd.random() < 0.2:
        return rnd.choice([0, 1, -1, 2047, -2048, 0x400, -0x400, 31, 32])
    return rnd.randrange(-2048, 2048)

RR = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
RI = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SI = ["slli", "srli", "srai"]
BR = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]

def alu_item():
    k = rnd.random()
    if k < 0.45:
        e("%s x%d, x%d, x%d" % (rnd.choice(RR), dst(), src(), src()))
    elif k < 0.75:
        e("%s x%d, x%d, %d" % (rnd.choice(RI), dst(), src(), imm12()))
    elif k < 0.90:
        e("%s x%d, x%d, %d" % (rnd.choice(SI), dst(), src(), rnd.randrange(32)))
    elif k < 0.95:
        e("lui x%d, %d" % (dst(), rnd.randrange(1 << 20)))
    else:
        e("auipc x%d, %d" % (dst(), rnd.randrange(1 << 20)))

def mem_item():
    if rnd.random() < 0.5:
        op = rnd.choice(["lb", "lbu", "lh", "lhu", "lw"])
        reg = dst()
    else:
        op = rnd.choice(["sb", "sh", "sw"])
        reg = src()
    size = {"b": 1, "h": 2, "w": 4}[op[1]]
    e("%s x%d, %d(x31)" % (op, reg, size * rnd.randrange(256 // size)))

def branch_item():
    lab = newlab()
    a = src()
    b = a if rnd.random() < 0.1 else src()
    e("%s x%d, x%d, %s" % (rnd.choice(BR), a, b, lab))
    for _ in range(rnd.randrange(1, 5)):
        alu_item()
    out.append(lab + ":")

def jal_item():
    lab = newlab()
    e("jal x%d, %s" % (dst(), lab))
    for _ in range(rnd.randrange(0, 4)):
        alu_item()
    out.append(lab + ":")

def jalr_item():
    imm = rnd.randrange(-64, 65)
    odd = 1 if rnd.random() < 0.5 else 0
    e("auipc x29, 0")
    e("addi x29, x29, %d" % (12 - imm + odd))
    e("jalr x%d, %d(x29)" % (dst(), imm))

def loop_item():
    top = newlab()
    e("li x30, %d" % rnd.randrange(1, 9))
    out.append(top + ":")
    for _ in range(rnd.randrange(2, 6)):
        alu_item() if rnd.random() < 0.7 else mem_item()
    e("addi x30, x30, -1")
    e("bne x30, x0, %s" % top)

out.append(".section .text.start")
out.append(".globl _start")
out.append("_start:")
e("li x31, 4096")
for r in range(1, 29):
    e("li x%d, %d" % (r, val32()))
e("li x29, 0")
e("li x30, 0")
for w in range(64):
    e("sw x%d, %d(x31)" % (rnd.randrange(1, 29), 4 * w))
for _ in range(rnd.randrange(80, 140)):
    k = rnd.random()
    if k < 0.55:
        alu_item()
    elif k < 0.75:
        mem_item()
    elif k < 0.85:
        branch_item()
    elif k < 0.90:
        loop_item()
    elif k < 0.95:
        jal_item()
    else:
        jalr_item()
e("ebreak")
print("\n".join(out))
