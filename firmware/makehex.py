#!/usr/bin/env python3
import sys


def main():
    if len(sys.argv) < 3:
        print("usage: makehex.py in.bin out.hex [limit_bytes]", file=sys.stderr)
        return 2

    inp = sys.argv[1]
    outp = sys.argv[2]
    limit = int(sys.argv[3], 0) if len(sys.argv) > 3 else 8192

    if limit % 4 != 0:
        print("error: limit must be a multiple of 4", file=sys.stderr)
        return 2

    with open(inp, "rb") as f:
        data = bytearray(f.read())

    if len(data) > limit:
        print("error: image size %d exceeds limit %d" % (len(data), limit), file=sys.stderr)
        return 1

    if len(data) < limit:
        data.extend(b"\x00" * (limit - len(data)))

    with open(outp, "w") as f:
        for i in range(0, limit, 4):
            word = data[i] | (data[i + 1] << 8) | (data[i + 2] << 16) | (data[i + 3] << 24)
            f.write("%08x\n" % word)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
