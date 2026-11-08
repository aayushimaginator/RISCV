#!/bin/sh
# usage: tools/run_riscv_tests.sh   (clones riscv-tests into build/, runs rv32ui on the core TB)
CROSS=${CROSS:-riscv64-unknown-elf-}
T=build/riscv-tests; d=build/rvt
mkdir -p $d
[ -d $T ] || git clone -q --depth 1 https://github.com/riscv-software-src/riscv-tests $T || exit 1
iverilog -g2001 -o $d/core_tb.vvp tb/rv32i_core_tb.v rtl/rv32i_core.v rtl/rv32i_decoder.v \
  rtl/rv32i_immgen.v rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v || exit 1
pass=0; fail=0; skip=0; tc=0; ti=0
for n in simple add addi and andi auipc beq bge bgeu blt bltu bne jal jalr lb lbu lh lhu lui lw or ori sb sh sw sll slli slt slti sltiu sltu sra srai srl srli sub xor xori ld_st st_ld; do
  s=$T/isa/rv64ui/$n.S
  [ -f $s ] || { echo "SKIP  $n (not in this riscv-tests version)"; skip=$((skip+1)); continue; }
  if ! ${CROSS}gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -I tests/rvtest_env -I $T/isa/macros/scalar \
       -T firmware/link.ld $s -o $d/$n.elf 2> $d/$n.err; then
    echo "BUILD-FAIL $n"; head -3 $d/$n.err; fail=$((fail+1)); continue; fi
  ${CROSS}objcopy -O binary $d/$n.elf $d/$n.bin
  if [ "$(stat -c %s $d/$n.bin)" -gt 8192 ]; then echo "TOO-BIG $n"; fail=$((fail+1)); continue; fi
  python3 firmware/makehex.py $d/$n.bin $d/$n.hex || exit 1
  vvp $d/core_tb.vvp +HEX=$d/$n.hex +DUMP=$d/$n.dump +MAXCYCLES=500000 > $d/$n.log 2>&1
  gp=$(awk '$1=="x3"{print $2}' $d/$n.dump)
  python3 tools/rv32i_iss.py $d/$n.hex $d/$n.iss > $d/$n.iss.log 2>&1
  sed "s/xxxxxxxx/00000000/" $d/$n.dump > $d/$n.dumpn
  if python3 tools/compare_dumps.py $d/$n.dumpn $d/$n.iss > /dev/null 2>&1; then iss=agree; else iss=ISS-DIFF; fi
  if grep -q HALTED $d/$n.log && [ "$gp" = "00000001" ]; then
    echo "PASS  $n ($iss)"; pass=$((pass+1))
    cy=$(awk '$1=="cycles"{print $2}' $d/$n.dump); ins=$(sed -n "s/.*after \([0-9]*\) instr.*/\1/p" $d/$n.iss.log); tc=$((tc+cy)); ti=$((ti+ins))
  else
    echo "FAIL  $n gp=$gp $(grep RESULT $d/$n.log) ($iss)"; fail=$((fail+1))
  fi
done
echo "total: $ti instructions in $tc cycles (CPI x1000 = $((tc*1000/ti)))"
echo "rv32ui: $pass pass, $fail fail, $skip skipped"
[ $fail -eq 0 ] && echo PASS || echo FAIL
