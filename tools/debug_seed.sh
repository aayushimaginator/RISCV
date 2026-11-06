#!/bin/sh
seed=${1:-1}
CROSS=${CROSS:-riscv64-unknown-elf-}
d=build/rand
tools/run_random.sh 1 $seed || exit 1
python3 tools/rv32i_iss.py $d/p.hex $d/iss.dump 2000000 $d/iss.trace
vvp $d/core_tb.vvp +HEX=$d/p.hex +DUMP=$d/core.dump +MAXCYCLES=200000 +TRACE=$d/core.trace > $d/vvp.log 2>&1
echo "--- first divergence ---"
python3 tools/first_divergence.py $d/core.trace $d/iss.trace
echo "--- final state compare ---"
python3 tools/compare_dumps.py $d/core.dump $d/iss.dump | head -12
${CROSS}objdump -d $d/p.elf > $d/p.dis
echo "disassembly: $d/p.dis   (look up the pc from the divergence line)"
