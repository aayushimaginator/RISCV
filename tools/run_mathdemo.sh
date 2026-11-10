#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/mathdemo
mkdir -p "$OUT"
python3 tools/gen_mathexp.py
gcc -DHOST -O1 -Wall -Wextra -Ifirmware -o "$OUT/host" firmware/mathdemo.c
"$OUT/host" | tail -n 3
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware -T firmware/link.ld firmware/start.S firmware/mathdemo.c -o "$OUT/mathdemo.elf"
${CROSS}objcopy -O binary "$OUT/mathdemo.elf" "$OUT/mathdemo.bin"
python3 firmware/makehex.py "$OUT/mathdemo.bin" "$OUT/mathdemo.hex"
${CROSS}size "$OUT/mathdemo.elf"
iverilog -g2012 -DHEXFILE='"build/mathdemo/mathdemo.hex"' -o "$OUT/sim.vvp" rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v rtl/ram_lutram.v rtl/uart_tx.v rtl/seg7_driver.v rtl/mul32.v tb/soc_selftest_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SELFTEST SIM PASS" "$OUT/sim.log"
echo "RUN_MATHDEMO: ALL GATES PASS"
