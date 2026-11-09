# Urbana implementation of RV32I

RV32I CPU project on the RealDigital Urbana (Spartan-7 XC7S50, speed grade -2), for an MPMC course.

## Status
- Phase 0: SoC around unmodified PicoRV32 (UART + 16 LEDs). Simulation PASS, Vivado timing met at 100 MHz. **Board test: verified on Urbana (UART greeting + LED sweep).**
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
    git clone --recursive https://github.com/aayushimaginator/RISCV.git
    make -C firmware DELAY_N=20
    iverilog -o soc_tb.vvp tb/soc_tb.v rtl/soc_top.v rtl/ram_lutram.v rtl/uart_tx.v third_party/picorv32/picorv32.v
    vvp soc_tb.vvp
    make -C firmware clean && make -C firmware
    vivado -mode batch -source build.tcl

## Tools
Code was generated with LLM assistance (Qwen for generation, Claude for review). All results above come from tools run locally.

## License
MIT for this repo's own code. third_party/picorv32 is ISC (YosysHQ).

## Phase 1: own 2-stage RV32I core (50 MHz)

| Item | Result |
|---|---|
| Clock | 100 MHz pin -> MMCM -> 50 MHz system clock (20 ns) |
| Setup / hold slack | WNS +2.163 ns / WHS +0.090 ns (post-route, Vivado 2024.2) |
| Critical path | 17.6 ns: data-RAM read -> LSU -> forwarding -> branch compare -> next PC |
| Real Fmax | about 56 MHz (not 100 MHz) |
| Verification | 7 unit tests; 50/50 random programs match a Python ISS; SoC sim PASS |
| Board test | superseded by Phase 2 (never run on hardware) |

History: the single-cycle core failed 100 MHz (WNS -7.07 ns). The 2-stage version keeps
branch resolution and forwarding in one stage, so the critical path is not shorter. An
earlier commit claimed 100 MHz from a 20 ns constraint on a 100 MHz pin; that was wrong
and is corrected here with a real MMCM-derived clock.
Code was written with LLM assistance and independently verified.

### Compliance
- riscv-tests rv32ui: 40/40 pass (minimal ECALL-terminated env in `tests/rvtest_env`; `fence_i` and `ma_data` skipped as out of scope). Each result also agrees with the Python ISS.
- CPI on that suite: about 1.07 (short tests, includes pipeline fill).
- Run: `tools/run_riscv_tests.sh`

## Phase 2: 4-stage core (IF | EX | MEM | WB), 75 MHz

| Item | Result |
|---|---|
| Clock | 100 MHz pin -> MMCM -> 75 MHz system clock (13.33 ns) |
| Setup / hold slack | WNS +1.427 ns / WHS +0.048 ns (post-route, Vivado 2024.2) |
| Critical path | 11.9 ns: instruction reg -> decode/immgen -> ALU adder (JALR target) -> next PC |
| Estimated Fmax | about 84 MHz |
| Verification | unit tests; 200/200 random programs vs ISS; riscv-tests rv32ui 40/40; SoC sim PASS |
| CPI | about 1.08 on rv32ui (short tests, includes pipeline fill) |
| Board test | **verified on Urbana**: bitstream at 75 MHz prints `Hello, RV32I!` on UART and runs the LED sweep, about 2.8x faster than the PicoRV32 control on the same firmware |

Change from Phase 1: load data is registered at the end of MEM and forwarded from the WB
register, so the data-RAM read no longer sits in the branch-resolve path. One stall cycle on
load-use. UART divisor 651 for 75 MHz is not exercised by the simulation (the testbench
overrides it and uses a /2 clock), so it is only verified by arithmetic until the board test.

### Hardware bring-up notes (Urbana)
- One micro-USB cable into `PROG UART USB PWR` (J13) powers, programs and carries the UART (FT2232H, UART on the second ttyUSB, 115200 8N1). The USB-C port is external power only.
- Jumper `PWR SEL` on `USB`, power switch `SW16` on `ON`; all four POWER SUPPLY STATUS LEDs light.
- Control experiment first: PicoRV32 bitstream (`scripts/program.tcl`), then own core (`-tclargs <bitstream>`). Same firmware, same expected output.
