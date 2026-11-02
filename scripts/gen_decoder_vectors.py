#!/usr/bin/env python3
import random
random.seed(7)

SH = dict(reg_write=0, a_sel=1, b_sel=2, alu_op=3, mem_read=7, mem_write=8,
          wb_sel=9, is_branch=11, is_jal=12, is_jalr=13, halt=14)

def pack(d):
    return sum(v << SH[k] for k, v in d.items())

HALT = dict(halt=1)

def model(instr):
    op = instr & 0x7F
    f3 = (instr >> 12) & 7
    f7 = (instr >> 25) & 0x7F
    if (instr & 3) != 3:
        return HALT
    if op == 0x37:
        return dict(reg_write=1, wb_sel=3)
    if op == 0x17:
        return dict(reg_write=1, a_sel=1, b_sel=1)
    if op == 0x6F:
        return dict(reg_write=1, wb_sel=2, is_jal=1)
    if op == 0x67:
        return dict(reg_write=1, b_sel=1, wb_sel=2, is_jalr=1) if f3 == 0 else HALT
    if op == 0x63:
        return dict(is_branch=1) if f3 in (0, 1, 4, 5, 6, 7) else HALT
    if op == 0x03:
        return dict(reg_write=1, b_sel=1, mem_read=1, wb_sel=1) if f3 in (0, 1, 2, 4, 5) else HALT
    if op == 0x23:
        return dict(mem_write=1, b_sel=1) if f3 in (0, 1, 2) else HALT
    if op == 0x13:
        base = dict(reg_write=1, b_sel=1)
        if f3 in (0, 2, 3, 4, 6, 7):
            return dict(base, alu_op=f3)
        if f3 == 1:
            return dict(base, alu_op=1) if f7 == 0x00 else HALT
        if f7 == 0x00:
            return dict(base, alu_op=5)
        if f7 == 0x20:
            return dict(base, alu_op=13)
        return HALT
    if op == 0x33:
        base = dict(reg_write=1)
        if f7 == 0x00:
            return dict(base, alu_op=f3)
        if f7 == 0x20 and f3 == 0:
            return dict(base, alu_op=8)
        if f7 == 0x20 and f3 == 5:
            return dict(base, alu_op=13)
        return HALT
    if op == 0x0F:
        return {}
    return HALT

lines = []
for op in range(128):
    for f3 in range(8):
        for f7 in range(128):
            instr = ((f7 << 25) | (random.randrange(32) << 20) | (random.randrange(32) << 15)
                     | (f3 << 12) | (random.randrange(32) << 7) | op)
            lines.append("%08x %04x" % (instr, pack(model(instr))))
for fixed in (0x00000073, 0x00100073, 0x00000000):
    lines.append("%08x %04x" % (fixed, pack(model(fixed))))
open("tb/decoder_vectors.hex", "w").write("\n".join(lines) + "\n")
print(len(lines), "vectors written")
