#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/seg7
mkdir -p "$OUT"
iverilog -g2001 -o "$OUT/unit.vvp" rtl/seg7_driver.v tb/seg7_tb.v
vvp "$OUT/unit.vvp" | tee "$OUT/unit.log"
grep -q "SEG7 TB PASS" "$OUT/unit.log"
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -T firmware/link.ld firmware/start.S firmware/segtest.c -o "$OUT/segtest.elf"
${CROSS}objcopy -O binary "$OUT/segtest.elf" "$OUT/segtest.bin"
python3 firmware/makehex.py "$OUT/segtest.bin" "$OUT/segtest.hex"
iverilog -g2012 -DHEXFILE='"build/seg7/segtest.hex"' -o "$OUT/soc.vvp" rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v tb/soc_seg_tb.v
vvp "$OUT/soc.vvp" | tee "$OUT/soc.log"
grep -q "SEG7 SOC PASS" "$OUT/soc.log"
echo "RUN_SEG7: ALL GATES PASS"
