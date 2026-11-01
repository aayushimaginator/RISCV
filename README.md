# urbana-rv32i

RV32I CPU project on the RealDigital Urbana (Spartan-7 XC7S50, speed grade -2), for an MPMC course.

## Status
- Phase 0: SoC around unmodified PicoRV32 (UART + 16 LEDs). Simulation PASS, Vivado timing met at 100 MHz. **Board test pending.**
- Phase 1: own single-cycle RV32I core, in progress (ALU and branch comparator first).

## Phase 0 results (Vivado 2024.2, post-implementation, 100 MHz)
| Metric | Value |
|---|---|
| Slice LUTs | 2060 (6.3%) |
| LUT as Memory | 1068 |
| Slice registers | 615 |
| WNS / WHS | +2.102 ns / +0.101 ns |

Reports are in docs/reports/.

## Memory map
- 0x0000_0000 RAM, 8 KB
- 0x1000_0000 LED register (16 bits)
- 0x1000_0004 UART TX data
- 0x1000_0008 UART status (bit 0 = busy)

## Build
    git clone --recursive <repo-url>
    make -C firmware DELAY_N=20
    iverilog -o soc_tb.vvp tb/soc_tb.v rtl/soc_top.v rtl/ram_lutram.v rtl/uart_tx.v third_party/picorv32/picorv32.v
    vvp soc_tb.vvp
    make -C firmware clean && make -C firmware
    vivado -mode batch -source build.tcl

## Tools
Code was generated with LLM assistance (Qwen for generation, Claude for review). All results above come from tools run locally.

## License
MIT for this repo's own code. third_party/picorv32 is ISC (YosysHQ).
