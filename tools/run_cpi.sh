#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/cpi
mkdir -p "$OUT"

${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding \
    -O1 -Wall -Wextra -Ifirmware -T firmware/link.ld \
    firmware/start.S firmware/cpi.c -o "$OUT/cpi.elf"
${CROSS}objcopy -O binary "$OUT/cpi.elf" "$OUT/cpi.bin"
python3 firmware/makehex.py "$OUT/cpi.bin" "$OUT/cpi.hex"
${CROSS}size "$OUT/cpi.elf"

iverilog -g2012 -DHEXFILE='"build/cpi/cpi.hex"' -o "$OUT/sim.vvp" \
    rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v \
    rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v \
    rtl/ram_lutram.v rtl/uart_tx.v rtl/seg7_driver.v rtl/mul32.v \
    tb/soc_selftest_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SELFTEST SIM PASS" "$OUT/sim.log"

python3 tools/check_cpi.py --log "$OUT/sim.log"
echo "RUN_CPI: ALL GATES PASS"
