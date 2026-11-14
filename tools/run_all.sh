#!/usr/bin/env bash
# Run every simulation gate and print a summary. Hardware-only checks are not included.
#   tools/run_all.sh          all gates (a few minutes)
#   tools/run_all.sh --full   also 50 random programs against the Python ISS
set -u
cd "$(dirname "$0")/.."
GATES="run_unit_tests run_riscv_tests run_selftest run_seg7 run_cpi run_mulbench run_mathdemo run_mathdisp run_rxsoc run_calc run_ram16 run_coremark"
mkdir -p build/gates
fails=0
printf '%-18s %-6s %s\n' GATE RESULT SECONDS
for g in $GATES; do
    t0=$(date +%s)
    if bash "tools/$g.sh" > "build/gates/$g.log" 2>&1; then r=PASS; else r=FAIL; fails=$((fails + 1)); fi
    printf '%-18s %-6s %s\n' "$g" "$r" "$(( $(date +%s) - t0 ))"
done
if [ "${1:-}" = "--full" ]; then
    t0=$(date +%s)
    if sh tools/run_random.sh 50 1 > build/gates/run_random.log 2>&1; then r=PASS; else r=FAIL; fails=$((fails + 1)); fi
    printf '%-18s %-6s %s\n' run_random "$r" "$(( $(date +%s) - t0 ))"
fi
if [ "$fails" -eq 0 ]; then echo "ALL GATES PASS"; else echo "$fails GATE(S) FAILED (see build/gates/*.log)"; exit 1; fi
