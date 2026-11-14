#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CROSS="${CROSS:-riscv64-unknown-elf-}"
OUT=build/coremark
mkdir -p "$OUT"

for f in core_list_join.c core_main.c core_matrix.c core_state.c core_util.c coremark.h LICENSE.md VERSION; do
    [ -f "third_party/coremark/$f" ] || { echo "missing third_party/coremark/$f"; exit 1; }
done

CM="third_party/coremark/core_list_join.c third_party/coremark/core_main.c third_party/coremark/core_matrix.c third_party/coremark/core_state.c third_party/coremark/core_util.c"
PORT="firmware/cm_port/core_portme.c firmware/cm_port/ee_printf_min.c"
INC="-Ifirmware/cm_port -Ithird_party/coremark"
DEFS="-DPERFORMANCE_RUN=1 -DITERATIONS=1 -DCLOCKS_PER_SEC=75000000 -DTOTAL_DATA_SIZE=2000 -DHAS_FLOAT=0 -DMAIN_HAS_NOARGC=1"
BASE="-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles -include stddef.h -include stdint.h"

${CROSS}gcc -march=rv32i -mabi=ilp32 -c firmware/start16.S -o "$OUT/start16.o"

build_one() {
    local opt="$1"
    ${CROSS}gcc $BASE $opt $DEFS -DFLAGS_STR="\"$opt rv32i ilp32 freestanding nostdlib\"" $INC \
        -T firmware/link16.ld "$OUT/start16.o" $CM $PORT -lgcc \
        -o "$OUT/coremark$opt.elf" 2>"$OUT/build$opt.err"
    ${CROSS}size "$OUT/coremark$opt.elf"
}

echo "=== size -O2 ==="
build_one -O2
dec_o2=$(${CROSS}size "$OUT/coremark-O2.elf" 2>/dev/null | awk 'NR==2{print $4}')
echo "=== size -Os ==="
build_one -Os
dec_os=$(${CROSS}size "$OUT/coremark-Os.elf" 2>/dev/null | awk 'NR==2{print $4}')

if [ "$dec_o2" -le 13312 ]; then
    ELF="$OUT/coremark-O2.elf"; DEC="$dec_o2"; CHOSEN="-O2"
elif [ "$dec_os" -le 13312 ]; then
    ELF="$OUT/coremark-Os.elf"; DEC="$dec_os"; CHOSEN="-Os"
    echo "NOTE: -O2 too big (dec=$dec_o2); using -Os (dec=$dec_os)"
else
    echo "ERROR: neither -O2 ($dec_o2) nor -Os ($dec_os) fits 13312" >&2
    exit 1
fi
echo "CHOSEN=$CHOSEN dec=$DEC (limit 13312, 3KB stack headroom)"

${CROSS}objcopy -O binary "$ELF" "$OUT/coremark.bin"
python3 firmware/makehex.py "$OUT/coremark.bin" "$OUT/coremark.hex" 16384
${CROSS}size "$ELF"

iverilog -g2012 -DHEXFILE="\"$OUT/coremark.hex\"" -o "$OUT/sim.vvp" \
    rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v \
    rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v \
    rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v \
    tb/soc_cm_tb.v
vvp "$OUT/sim.vvp" | tee "$OUT/sim.log"
grep -q "COREMARK SIM PASS" "$OUT/sim.log"

echo "--- machine-readable lines ---"
grep -E "^(Total ticks|Iterations) +:" "$OUT/sim.log"
echo "RUN_COREMARK: ALL GATES PASS"
