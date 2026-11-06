#!/bin/sh
mkdir -p build/unit
t() {
  name=$1; shift
  if iverilog -g2001 -o build/unit/$name.vvp "$@" 2>build/unit/$name.err; then
    out=$(vvp build/unit/$name.vvp 2>&1 | grep -E '^(KAT )?(PASS|FAIL)' | head -1)
    echo "$name: ${out:-NO RESULT}"
  else
    echo "$name: COMPILE ERROR (see build/unit/$name.err)"
  fi
}
t alu_kat    rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v tb/rv32i_alu_kat.v
t alu_rand   rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v tb/rv32i_alu_tb.v
t regfile    rtl/rv32i_regfile.v tb/rv32i_regfile_tb.v
t immgen_vec rtl/rv32i_immgen.v tb/rv32i_immgen_vec_tb.v
t decoder_vec rtl/rv32i_decoder.v tb/rv32i_decoder_vec_tb.v
t decoder_tb rtl/rv32i_decoder.v tb/rv32i_decoder_tb.v
t lsu_tb     rtl/rv32i_lsu.v tb/rv32i_lsu_tb.v
