#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/mulbench
mkdir -p "$OUT"
iverilog -g2001 -o "$OUT/unit.vvp" rtl/mul32.v tb/mul32_tb.v
vvp "$OUT/unit.vvp" | tee "$OUT/unit.log"
grep -q "MUL32 TB PASS" "$OUT/unit.log"
python3 tools/gen_mulexp.py
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware -T firmware/link.ld firmware/start.S firmware/mulbench.c -o "$OUT/mulbench.elf"
${CROSS}objcopy -O binary "$OUT/mulbench.elf" "$OUT/mulbench.bin"
python3 firmware/makehex.py "$OUT/mulbench.bin" "$OUT/mulbench.hex"
${CROSS}size "$OUT/mulbench.elf"
iverilog -g2012 -DHEXFILE='"build/mulbench/mulbench.hex"' -o "$OUT/sim.vvp" rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v rtl/ram_lutram.v rtl/uart_tx.v rtl/seg7_driver.v rtl/mul32.v tb/soc_selftest_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SELFTEST SIM PASS" "$OUT/sim.log"
echo "RUN_MULBENCH: ALL GATES PASS"
