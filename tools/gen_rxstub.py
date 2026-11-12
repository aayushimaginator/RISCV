#!/usr/bin/env python3
"""Hand-assembled RX register test program (no compiler needed). Writes a hex image.
Behaviour: poll 0x10000034; on valid, ack (write 0 = pop) and show byte on LED.
On byte 0x7E: busy-wait ~16k cycles (so the TB can fill the FIFO), show the raw RX
register (overrun|valid|head) on the LEDs, then drain: pop every byte and show it."""
import sys

def r_(n): return n & 31
def lui(rd, imm20):        return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37
def addi(rd, rs, imm):     return ((imm & 0xFFF) << 20) | (rs << 15) | (0 << 12) | (rd << 7) | 0x13
def andi(rd, rs, imm):     return ((imm & 0xFFF) << 20) | (rs << 15) | (7 << 12) | (rd << 7) | 0x13
def lw(rd, rs, off):       return ((off & 0xFFF) << 20) | (rs << 15) | (2 << 12) | (rd << 7) | 0x03
def sw(rs2, rs1, off):     return (((off >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((off & 31) << 7) | 0x23
def br(f3, rs1, rs2, off):
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | 0x63
def jal(rd, off):
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | (((o >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F

prog = []
labels = {}
def L(n): labels[n] = len(prog) * 4
def I(f): prog.append(f)       # f: callable(pc) -> word, or int

I(lui(1, 0x10000))                                   # x1 = 0x10000000
L("poll")
I(lw(2, 1, 0x34))
I(andi(3, 2, 0x100))
I(lambda pc: br(0, 3, 0, labels["poll"] - pc))       # beq x3,x0,poll
I(sw(0, 1, 0x34))                                    # ack
I(andi(2, 2, 0xFF))
I(sw(2, 1, 0))                                       # LED = byte
I(addi(4, 0, 0x7E))
I(lambda pc: br(1, 2, 4, labels["poll"] - pc))       # bne x2,x4,poll
I(lui(5, 4))                                         # x5 = 16384
L("delay")
I(addi(5, 5, -1))
I(lambda pc: br(1, 5, 0, labels["delay"] - pc))      # bne x5,x0,delay
I(lw(2, 1, 0x34))
I(sw(2, 1, 0))                                       # LED = raw register
L("drain")
I(lw(2, 1, 0x34))
I(andi(3, 2, 0x100))
I(lambda pc: br(0, 3, 0, labels["drain"] - pc))      # beq x3,x0,drain
I(sw(0, 1, 0x34))                                    # pop
I(andi(2, 2, 0xFF))
I(sw(2, 1, 0))                                       # LED = byte
I(lambda pc: jal(0, labels["drain"] - pc))

words = [f(i * 4) if callable(f) else f for i, f in enumerate(prog)]
words += [0] * (2048 - len(words))
open(sys.argv[1], "w").write("".join("%08x\n" % w for w in words))
