#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/calc
mkdir -p "$OUT"
gcc -DHOST -O1 -Wall -Wextra -Ifirmware -o "$OUT/host" firmware/calc.c
python3 tools/check_calc.py
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -Ifirmware -T firmware/link.ld firmware/start.S firmware/calc.c -o "$OUT/calc.elf"
${CROSS}size "$OUT/calc.elf"
if ${CROSS}objdump -d "$OUT/calc.elf" | grep -qE "[[:space:]](mul|mulh|mulhu|mulhsu|div|divu|rem|remu)[[:space:]]|__mul|__div"; then
    echo "FAIL: M-extension or libgcc call in calc.elf"; exit 1
fi

# SoC sim: short display hold so the cos/sin alternation is visible in simulation
${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O1 -Wall -Wextra -DHOLD_CYCLES=20000u -Ifirmware -T firmware/link.ld firmware/start.S firmware/calc.c -o "$OUT/calc_sim.elf"
${CROSS}objcopy -O binary "$OUT/calc_sim.elf" "$OUT/calc_sim.bin"
python3 firmware/makehex.py "$OUT/calc_sim.bin" "$OUT/calc.hex"
iverilog -g2012 -DHEXFILE='"build/calc/calc.hex"' -o "$OUT/sim.vvp" \
    rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v \
    rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v \
    rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v \
    tb/soc_calc_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SOC CALC SIM PASS" "$OUT/sim.log"
echo "RUN_CALC: ALL GATES PASS"
