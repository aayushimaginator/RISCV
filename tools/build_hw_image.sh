#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -lt 2 ]; then
    echo "usage: tools/build_hw_image.sh NAME SOURCE.c [extra gcc flags]"
    exit 2
fi
NAME="$1"
SRC="$2"
shift 2
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT="build/$NAME"
mkdir -p "$OUT"

restore() {
    make -C firmware clean > /dev/null
    make -C firmware > /dev/null
    cp firmware/firmware.hex rtl/firmware.hex
    echo "restored normal firmware hex"
}
trap restore EXIT

${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware "$@" -T firmware/link.ld firmware/start.S "$SRC" -o "$OUT/$NAME.elf"
${CROSS}objcopy -O binary "$OUT/$NAME.elf" "$OUT/$NAME.bin"
python3 firmware/makehex.py "$OUT/$NAME.bin" "$OUT/$NAME.hex"
cp "$OUT/$NAME.hex" firmware/firmware.hex

vivado -mode batch -source build_rv32i.tcl > "$OUT/vivado.log" 2>&1 || true
grep -E "^Bitstream:|ERROR|CRITICAL" "$OUT/vivado.log" | tail -n 8
cp vivado_rv32i/phase1.runs/impl_1/soc_top_rv32i.bit "build/$NAME.bit"
echo "saved build/$NAME.bit"
grep -h -A2 "WNS(ns)" vivado_rv32i/phase1.runs/impl_1/*timing_summary*.rpt | sed -n '1,3p'
