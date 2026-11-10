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

if ! vivado -mode batch -source build_rv32i.tcl > "$OUT/vivado.log" 2>&1; then
    echo "BUILD FAILED: Vivado exited non-zero; bitstream NOT saved" >&2
    grep -E "ERROR|CRITICAL" "$OUT/vivado.log" | tail -n 8 >&2 || true
    exit 1
fi
if ! grep -q "Bitgen Completed Successfully" "$OUT/vivado.log"; then
    echo "BUILD FAILED: no bitgen completion in log; bitstream NOT saved" >&2
    exit 1
fi
if grep -q "CRITICAL WARNING: \[Timing 38-282\]" "$OUT/vivado.log"; then
    echo "WARNING: timing NOT met in this image" >&2
fi
grep -E "^Bitstream:|CRITICAL" "$OUT/vivado.log" | tail -n 8
cp vivado_rv32i/phase1.runs/impl_1/soc_top_rv32i.bit "build/$NAME.bit"
echo "saved build/$NAME.bit"

mkdir -p "docs/reports/$NAME"
cp reports_rv32i/post_impl_timing_summary.rpt "docs/reports/$NAME/timing_summary.rpt"
cp reports_rv32i/critical_path.rpt "docs/reports/$NAME/critical_path.rpt"
cp reports_rv32i/post_impl_utilization.rpt "docs/reports/$NAME/utilization.rpt"
echo "snapshotted reports to docs/reports/$NAME/"

grep -h -A2 "WNS(ns)" vivado_rv32i/phase1.runs/impl_1/*timing_summary*.rpt | sed -n '1,3p'
