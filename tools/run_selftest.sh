#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/selftest
mkdir -p "$OUT"
python3 tools/check_selftest.py
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -T firmware/link.ld firmware/start.S firmware/selftest.c -o "$OUT/selftest.elf"
${CROSS}objcopy -O binary "$OUT/selftest.elf" "$OUT/selftest.bin"
python3 firmware/makehex.py "$OUT/selftest.bin" "$OUT/selftest.hex"
${CROSS}size "$OUT/selftest.elf"
${CROSS}objdump -d "$OUT/selftest.elf" > "$OUT/selftest.dis"
missing=0
for mn in sra srai sltu seqz lb lbu lh lhu sb sh jalr bgeu bltu blt bge; do
  if grep -qE "[[:space:]]${mn}[[:space:]]" "$OUT/selftest.dis"; then echo "have $mn"; else echo "MISSING $mn"; missing=1; fi
done
[ "$missing" -eq 0 ] || { echo "objdump gate FAIL"; exit 1; }
iverilog -g2012 -o "$OUT/sim.vvp" rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v rtl/ram_lutram.v rtl/uart_tx.v rtl/seg7_driver.v rtl/mul32.v tb/soc_selftest_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SELFTEST SIM PASS" "$OUT/sim.log"
echo "RUN_SELFTEST: ALL GATES PASS"
