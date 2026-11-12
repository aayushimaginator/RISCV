#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/ram16
mkdir -p "$OUT"

${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware -T firmware/link16.ld firmware/start16.S firmware/ramtest.c -o "$OUT/ramtest.elf"
${CROSS}objcopy -O binary "$OUT/ramtest.elf" "$OUT/ramtest.bin"
python3 firmware/makehex.py "$OUT/ramtest.bin" "$OUT/ramtest.hex" 16384
${CROSS}size "$OUT/ramtest.elf"

iverilog -g2012 -DHEXFILE='"build/ram16/ramtest.hex"' -o "$OUT/sim.vvp" \
  rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v \
  rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v \
  rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v \
  tb/soc_selftest_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SELFTEST SIM PASS" "$OUT/sim.log"
echo "RUN_RAM16: ALL GATES PASS"
