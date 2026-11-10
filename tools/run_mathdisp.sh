#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/mathdisp
mkdir -p "$OUT"
gcc -DHOST -O1 -Wall -Wextra -Ifirmware -o "$OUT/host" firmware/mathdisp.c
python3 tools/check_mathdisp.py
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware -T firmware/link.ld firmware/start.S firmware/mathdisp.c -o "$OUT/mathdisp.elf"
${CROSS}size "$OUT/mathdisp.elf"
echo "RUN_MATHDISP: ALL GATES PASS"
