#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/rxsoc
mkdir -p "$OUT"
iverilog -g2012 -o build/rx.vvp rtl/uart_rx.v tb/uart_rx_tb.v
vvp build/rx.vvp | tee "$OUT/unit.log"
grep -q "UART_RX UNIT PASS" "$OUT/unit.log"
python3 tools/gen_rxstub.py "$OUT/rxstub.hex"
iverilog -g2012 -DHEXFILE='"build/rxsoc/rxstub.hex"' -o "$OUT/sim.vvp" \
    rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v \
    rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v \
    rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v \
    tb/soc_rx_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "SOC RX SIM PASS" "$OUT/sim.log"
echo "RUN_RXSOC: ALL GATES PASS"
