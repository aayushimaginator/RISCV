#!/usr/bin/env python3
import random
M32 = 0xFFFFFFFF
random.seed(1)

def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v

def reg():
    return random.randrange(32)

def enc_i(op, f3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def enc_s(op, f3, rs1, rs2, imm):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op

def enc_b(op, f3, rs1, rs2, imm):
    return ((((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15)
            | (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op)

def enc_u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op

def enc_j(op, rd, imm):
    return ((((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20)
            | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op)

vecs = []
def add(instr, exp):
    vecs.append((instr & M32, exp & M32))

E12 = [0, 1, -1, 2047, -2048, 0x400, -0x400, 0x555, -0x555, 5]
I_FORMS = [(0x03, 0), (0x03, 1), (0x03, 2), (0x03, 4), (0x03, 5),
           (0x13, 0), (0x13, 1), (0x13, 2), (0x13, 3), (0x13, 4), (0x13, 5), (0x13, 6), (0x13, 7),
           (0x67, 0)]
for op, f3 in I_FORMS:
    for imm in E12 + [random.randrange(-2048, 2048) for _ in range(400)]:
        add(enc_i(op, f3, reg(), reg(), imm), sext(imm, 12))

for f3 in (0, 1, 2):
    for imm in E12 + [random.randrange(-2048, 2048) for _ in range(400)]:
        add(enc_s(0x23, f3, reg(), reg(), imm), sext(imm, 12))

EB = [0, 2, -2, 4094, -4096, 2048, -2048, 0x7FE, 0xAAA, -0xAAA]
for f3 in (0, 1, 4, 5, 6, 7):
    for imm in EB + [random.randrange(-4096, 4096, 2) for _ in range(400)]:
        add(enc_b(0x63, f3, reg(), reg(), imm), imm)

EJ = [0, 2, -2, 1048574, -1048576, 2048, -2048, 0x7FFFE, 0xFF000, -0xFF000, 0x55554, -0x55554]
for imm in EJ + [random.randrange(-1048576, 1048576, 2) for _ in range(2000)]:
    add(enc_j(0x6F, reg(), imm), imm)

for op in (0x37, 0x17):
    for imm20 in [0, 1, 0x80000, 0xFFFFF, 0x7FFFF, 0x12345] + [random.randrange(0x100000) for _ in range(400)]:
        add(enc_u(op, reg(), imm20), imm20 << 12)

with open("tb/immgen_vectors.hex", "w") as f:
    for i, e in vecs:
        f.write("%08x %08x\n" % (i, e))
print(len(vecs), "vectors written")
