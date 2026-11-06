#!/bin/sh
# usage: tools/run_random.sh <count> [first_seed]     (env: ALU=<alternate alu file>)
N=${1:-50}; S0=${2:-1}
CROSS=${CROSS:-riscv64-unknown-elf-}
ALU=${ALU:-rtl/rv32i_alu.v}
d=build/rand
mkdir -p $d
iverilog -g2001 -o $d/core_tb.vvp tb/rv32i_core_tb.v rtl/rv32i_core.v rtl/rv32i_decoder.v \
  rtl/rv32i_immgen.v rtl/rv32i_regfile.v $ALU rtl/rv32i_branch_cmp.v ${LSU:-rtl/rv32i_lsu.v} || exit 1
fail=0; i=0
while [ $i -lt $N ]; do
  seed=$((S0 + i))
  python3 tools/gen_random_prog.py $seed > $d/p.S || exit 1
  ${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T firmware/link.ld $d/p.S -o $d/p.elf || exit 1
  ${CROSS}objcopy -O binary $d/p.elf $d/p.bin
  if [ "$(stat -c %s $d/p.bin)" -gt 4096 ]; then echo "seed $seed: program too big"; exit 1; fi
  python3 firmware/makehex.py $d/p.bin $d/p.hex || exit 1
  python3 tools/rv32i_iss.py $d/p.hex $d/iss.dump > $d/iss.log || exit 1
  vvp $d/core_tb.vvp +HEX=$d/p.hex +DUMP=$d/core.dump +MAXCYCLES=200000 > $d/vvp.log 2>&1
  if ! python3 tools/compare_dumps.py $d/core.dump $d/iss.dump > $d/cmp.log; then
    echo "seed $seed: MISMATCH"; head -8 $d/cmp.log
    cp $d/p.S $d/fail_$seed.S; fail=$((fail + 1))
  fi
  i=$((i + 1))
done
echo "random programs: $N run, $fail failed"
if [ $fail -eq 0 ]; then echo PASS; else echo FAIL; fi
