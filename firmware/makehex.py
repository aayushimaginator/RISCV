#!/usr/bin/env python3

import sys

def main():
    if len(sys.argv) != 3:
        print("usage: makehex.py firmware.bin firmware.hex", file=sys.stderr)
        return 1

    bin_path = sys.argv[1]
    hex_path = sys.argv[2]

    with open(bin_path, "rb") as f:
        data = f.read()

    if len(data) > 8192:
        print(f"ERROR: firmware is {len(data)} bytes, exceeds 8192 bytes", file=sys.stderr)
        return 1

    # Pad to exactly 8192 bytes (2048 words) to prevent Icarus $readmemh 
    # from leaving trailing words as 'x'
    if len(data) < 8192:
        data = data + b"\x00" * (8192 - len(data))

    words = []
    for i in range(0, len(data), 4):
        w = (
            data[i + 0]
            | (data[i + 1] << 8)
            | (data[i + 2] << 16)
            | (data[i + 3] << 24)
        )
        words.append(f"{w:08x}")

    with open(hex_path, "w") as f:
        for w in words:
            f.write(w + "\n")

    return 0

if __name__ == "__main__":
    sys.exit(main())
