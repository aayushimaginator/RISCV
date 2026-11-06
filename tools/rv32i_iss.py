#!/usr/bin/env python3
"""Independent RV32I reference simulator, written from the ISA spec.
usage: rv32i_iss.py prog.hex out.dump [max_steps]"""
import sys

M32 = 0xFFFFFFFF
MEM_BYTES = 8192
TRACE = []

def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v

def run(words, max_steps):
    mem = bytearray(MEM_BYTES)
    for i, w in enumerate(words[:MEM_BYTES // 4]):
        mem[4*i:4*i+4] = w.to_bytes(4, "little")
    x = [0] * 32
    pc = 0
    steps = 0

    def chk(addr, n):
        if addr < 0 or addr + n > MEM_BYTES:
            raise SystemExit("ISS: access outside RAM at %08x" % addr)

    def load(addr, f3):
        if f3 in (0, 4):
            chk(addr, 1)
            v = mem[addr]
            return (sext(v, 8) & M32) if f3 == 0 else v
        if f3 in (1, 5):
            a = addr & ~1
            chk(a, 2)
            v = int.from_bytes(mem[a:a+2], "little")
            return (sext(v, 16) & M32) if f3 == 1 else v
        a = addr & ~3
        chk(a, 4)
        return int.from_bytes(mem[a:a+4], "little")

    def store(addr, v, f3):
        if f3 == 0:
            chk(addr, 1)
            mem[addr] = v & 0xFF
        elif f3 == 1:
            a = addr & ~1
            chk(a, 2)
            mem[a:a+2] = (v & 0xFFFF).to_bytes(2, "little")
        else:
            a = addr & ~3
            chk(a, 4)
            mem[a:a+4] = (v & M32).to_bytes(4, "little")

    timed_out = True
    while steps < max_steps:
        if (pc & 3) or pc + 4 > MEM_BYTES:
            timed_out = False
            break
        ins = int.from_bytes(mem[pc:pc+4], "little")
        if (ins & 3) != 3:
            timed_out = False
            break
        op = ins & 0x7F
        rd = (ins >> 7) & 31
        f3 = (ins >> 12) & 7
        a = (ins >> 15) & 31
        b = (ins >> 20) & 31
        f7 = (ins >> 25) & 0x7F
        nxt = (pc + 4) & M32
        wr = None
        if op == 0x37:
            wr = ins & 0xFFFFF000
        elif op == 0x17:
            wr = (pc + (ins & 0xFFFFF000)) & M32
        elif op == 0x6F:
            imm = sext(((ins >> 31) << 20) | (((ins >> 12) & 0xFF) << 12)
                       | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
            wr = nxt
            nxt = (pc + imm) & M32
        elif op == 0x67:
            if f3 != 0:
                timed_out = False
                break
            imm = sext(ins >> 20, 12)
            wr = nxt
            nxt = ((x[a] + imm) & M32) & ~1
        elif op == 0x63:
            imm = sext(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11)
                       | (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
            sa, sb = sext(x[a], 32), sext(x[b], 32)
            ua, ub = x[a], x[b]
            t = {0: ua == ub, 1: ua != ub, 4: sa < sb, 5: sa >= sb,
                 6: ua < ub, 7: ua >= ub}.get(f3)
            if t is None:
                timed_out = False
                break
            if t:
                nxt = (pc + imm) & M32
        elif op == 0x03:
            if f3 not in (0, 1, 2, 4, 5):
                timed_out = False
                break
            wr = load((x[a] + sext(ins >> 20, 12)) & M32, f3)
        elif op == 0x23:
            if f3 not in (0, 1, 2):
                timed_out = False
                break
            imm = sext(((ins >> 25) << 5) | ((ins >> 7) & 0x1F), 12)
            store((x[a] + imm) & M32, x[b], f3)
        elif op == 0x13:
            imm = sext(ins >> 20, 12)
            sh = (ins >> 20) & 31
            if f3 == 0:
                v = x[a] + imm
            elif f3 == 2:
                v = 1 if sext(x[a], 32) < imm else 0
            elif f3 == 3:
                v = 1 if x[a] < (imm & M32) else 0
            elif f3 == 4:
                v = x[a] ^ (imm & M32)
            elif f3 == 6:
                v = x[a] | (imm & M32)
            elif f3 == 7:
                v = x[a] & (imm & M32)
            elif f3 == 1:
                if f7 != 0:
                    timed_out = False
                    break
                v = x[a] << sh
            else:
                if f7 == 0:
                    v = x[a] >> sh
                elif f7 == 0x20:
                    v = sext(x[a], 32) >> sh
                else:
                    timed_out = False
                    break
            wr = v & M32
        elif op == 0x33:
            sh = x[b] & 31
            if f7 == 0:
                v = {0: x[a] + x[b], 1: x[a] << sh,
                     2: int(sext(x[a], 32) < sext(x[b], 32)), 3: int(x[a] < x[b]),
                     4: x[a] ^ x[b], 5: x[a] >> sh, 6: x[a] | x[b], 7: x[a] & x[b]}[f3]
            elif f7 == 0x20 and f3 == 0:
                v = x[a] - x[b]
            elif f7 == 0x20 and f3 == 5:
                v = sext(x[a], 32) >> sh
            else:
                timed_out = False
                break
            wr = v & M32
        elif op == 0x0F:
            pass
        else:
            timed_out = False
            break
        if wr is not None and rd != 0:
            x[rd] = wr & M32
            TRACE.append("%08x %08x %d %08x" % (pc, ins, rd, wr & M32))
        else:
            TRACE.append("%08x %08x 0 00000000" % (pc, ins))
        pc = nxt
        steps += 1
    return x, pc, steps, mem, timed_out

def dump(path, x, pc, steps, mem):
    with open(path, "w") as f:
        f.write("x0 00000000\n")
        for i in range(1, 32):
            f.write("x%d %08x\n" % (i, x[i]))
        f.write("pc %08x\n" % pc)
        f.write("cycles %d\n" % steps)
        for i in range(2048):
            f.write("m%04x %08x\n" % (i, int.from_bytes(mem[4*i:4*i+4], "little")))

if __name__ == "__main__":
    words = [int(l.split()[0], 16) for l in open(sys.argv[1]) if l.strip()]
    ms = int(sys.argv[3]) if len(sys.argv) > 3 else 2000000
    x, pc, steps, mem, to = run(words, ms)
    dump(sys.argv[2], x, pc, steps, mem)
    if len(sys.argv) > 4:
        open(sys.argv[4], "w").write("\n".join(TRACE) + "\n")
    print("ISS: %s after %d instructions, pc=%08x" % ("TIMEOUT" if to else "halted", steps, pc))
