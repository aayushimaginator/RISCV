# RV32I on the RealDigital Urbana

A from-scratch RV32I CPU (4-stage pipeline) on the RealDigital Urbana board (Spartan-7 XC7S50-CSGA324), running at 75 MHz, with a small SoC around it: UART TX and RX (with a FIFO), 16 LEDs, an 8-digit seven-segment display, a cycle counter and a DSP48 multiplier. Built for an MPMC course project.

Everything below that says "board" was run on a real Urbana. Everything that says "simulation" was not. The board was returned to the lab at the end of the project, so a few late items are simulation-only; they are marked.

## Status

| Item | Simulation | Board |
|---|---|---|
| PicoRV32 control SoC (Phase 0) | pass | pass (`Hello, RV32I!`, LED sweep) |
| Own 4-stage core, 75 MHz | pass (units, 200 random programs vs ISS, riscv-tests rv32ui 40/40) | pass (same firmware, about 2.8x faster than the PicoRV32 control) |
| 55-check known-answer self-test | pass | pass |
| Seven-segment display | pass | pass |
| Cycle counter + hardware multiplier (12.7x) | pass | pass |
| cos/sin calculator readout (CORDIC) | pass | pass |
| CPI microbenchmarks | pass | pass, cycle counts identical to simulation |
| UART receive + 16-byte FIFO, interactive calculator | pass | pass, including pasting several lines at once |
| 16 KB RAM (was 8 KB) | pass, timing met | not run on the board |
| CoreMark port | CRCs match a native build | not run on the board, **no score claimed** |

## Architecture

- **Core:** RV32I, 4 stages (IF | EX | MEM | WB). Load-use costs 1 stall cycle, a taken branch or jump costs 1 bubble. Forwarding between stages (load data is registered at the end of MEM and forwarded from the WB register, which keeps the data-RAM read out of the branch path). No multiply instruction (RV32I only).
- **Clock:** 100 MHz pin, MMCM to 75 MHz. Post-route slack in the table below; an attempt at 100 MHz missed by 0.076 ns and was not pursued.
- **Memory:** 16 KB LUTRAM, 0x0000 to 0x3FFF, two async read ports (instruction and data). Existing 8 KB images still run unchanged.

| Address | Register |
|---|---|
| 0x0000_0000 to 0x0000_3FFF | RAM (16 KB) |
| 0x1000_0000 | LED (16 bits) |
| 0x1000_0004 | UART TX data |
| 0x1000_0008 | UART status (bit 0 = TX busy) |
| 0x1000_000C | SEG_DATA, 8 hex nibbles (nibble 0 = rightmost digit) |
| 0x1000_0010 | SEG_DP, decimal-point mask |
| 0x1000_0014 | cycle counter (free-running, 32 bit) |
| 0x1000_0020 / 24 | multiplier operands A / B |
| 0x1000_0028 / 2C | multiplier result LO / HI |
| 0x1000_0030 | multiplier status (bit 0 = busy) |
| 0x1000_0034 | UART RX FIFO: read `{overrun, valid, head[7:0]}`, write pops the head and clears overrun |

Pins: UART TX A16, UART RX B16, reset button J2, clock N15, seven-segment pins in `constraints/urbana.xdc`.

## Results (Vivado 2024.2, post-implementation, 75 MHz unless noted)

| Build | WNS | WHS | Notes |
|---|---|---|---|
| PicoRV32 control, 100 MHz | +2.102 ns | +0.101 ns | 2060 LUTs |
| Own 2-stage core, 50 MHz | +2.163 ns | +0.090 ns | real Fmax about 56 MHz; never run on the board |
| Own 4-stage core, hello image | +1.427 ns | +0.048 ns | est. Fmax about 84 MHz, CPI about 1.08 on rv32ui |
| Calculator + RX FIFO image (8 KB RAM) | +2.123 ns | +0.060 ns | 20,895 endpoints, none failing |
| 16 KB RAM image | +2.098 ns | +0.068 ns | 6,272 LUTs (19%), 4,146 of them as memory, 0 BRAM |

Reports are in `docs/reports/`. The single-cycle core failed 100 MHz (WNS -7.07 ns), which is why the project moved to a pipelined design. An early commit claimed 100 MHz from a constraint on the wrong clock; that was wrong and is corrected in the history.

## Verified on the board

**55-check self-test** (`firmware/selftest.c`). CRC-32, Fibonacci, bubble sort, all shift and compare forms, every branch type, lb/lbu/lh/lhu/sb/sh with sign extension, indirect calls through a function-pointer table. Expected values come from Python (`tools/check_selftest.py`), not from the firmware. Result: all 55 PASS, LEDs 0xAAAA. Instructions the compiler would rewrite are forced with inline asm so they really execute.

![UART output](docs/media/selftest_uart.png)
![LEDs 0xAAAA](docs/media/selftest_leds.jpg)

**Seven-segment display** (`rtl/seg7_driver.v`). Two common-anode 4-digit displays, one digit per display lit at a time in four phases (about 1 kHz frame) with an idle clock between phases to prevent ghosting. Firmware writes 0xCBF43926 (the CRC-32 of `123456789`) and the display reads `CbF4.3926`. The first build showed the digits reversed; the digit map was fixed on hardware.

![Display showing CbF4.3926](docs/media/seg7_crc.jpg)

**Cycle counter and DSP48 multiplier** (`rtl/mul32.v`, `firmware/mulbench.c`). Two-stage pipeline of four 16x16 products, not an ISA extension. 100 multiplies take 26,904 cycles in software and 2,111 through the peripheral: 12.7x, shown on the display as `0000012.7`.

![Display showing 12.7x](docs/media/mulbench_speedup.jpg)

**cos/sin on the display** (`firmware/mathdisp.c`). Q16.16 CORDIC with no multiplier. The display shows function (C or 5), angle, value, for example `C135 0.707`. The font has no minus sign, so a negative value lights the decimal point after the angle. `tools/check_mathdisp.py` checks all 48 screens against Python's math library.

[Video](docs/media/mathdisp_sweep.mp4)

**CPI microbenchmarks** (`firmware/cpi.c`). Six inline-asm loops with exactly known instruction counts, timed with the cycle counter. Every loop includes one taken closing branch, so the floor is (I+1)/I rather than 1.0.

| Bench | Instr/iter | Predicted cyc/iter | Measured (sim = board) | CPI |
|---|---|---|---|---|
| EMPTY | 2 | 3 | 12295 | 1.501 |
| ADD4 | 6 | 7 | 28682 | 1.167 |
| LW4 | 6 | 7 | 28681 | 1.167 |
| SW4 | 6 | 7 | 28682 | 1.167 |
| NOTAKEN | 6 | 7 | 28681 | 1.167 |
| LOADUSE | 6 | 9 | 36875 | 1.500 |

**Interactive calculator over UART** (`rtl/uart_rx.v`, `firmware/calc.c`). Type an angle and press Enter; the board prints cos and sin and the display alternates between them. The receiver (8N1, mid-bit sampling) feeds a 16-byte FIFO, so pasting several lines while results are still printing is safe; a byte arriving with the FIFO full is dropped and sets a sticky overrun flag. A simulation test that pastes two lines fails on the older 1-byte latch.

[Video](docs/media/calc_rx.mp4)

An all-LEDs image (`firmware/allleds.c`, 0xFFFF) was also verified on the board; it has no simulation gate by design.

## CoreMark: simulation only

`firmware/cm_port/` ports EEMBC CoreMark (sources unmodified in `third_party/coremark/`, pinned commit in `VERSION`, EEMBC's licence file included). Run it with `tools/run_coremark.sh`.

- The image fits the 16 KB RAM: 12.9 KB at `-O2`, 10.4 KB at `-Os`. Software multiply and divide come from libgcc.
- In simulation the CRCs equal what a native host build prints (seedcrc 0xe9f5, list 0xe714, matrix 0x1fd7, state 0x8e3a), so the core executes CoreMark correctly.
- One iteration takes 918,280 cycles at `-O2` (1,059,708 at `-Os`) in simulation.
- **This is not a CoreMark score.** EEMBC requires a run of at least 10 seconds, which needs the board, and the board was returned. A 1-iteration run therefore ends with CoreMark's own "ERROR! Must execute for at least 10 secs" and "Errors detected"; the simulation gate checks the CRCs instead. `tools/cm_score.py` refuses to report a number for any run that is too short or has errors.

## Reproduce

Needs `riscv64-unknown-elf-gcc`, `iverilog`, Python 3. Vivado 2024.2 only for bitstreams.

    git clone --recursive https://github.com/aayushimaginator/RISCV.git
    cd RISCV
    bash tools/run_all.sh          # every simulation gate, a few minutes
    bash tools/run_all.sh --full   # also 50 random programs against the Python ISS

Single gates: `tools/run_unit_tests.sh`, `run_riscv_tests.sh`, `run_selftest.sh`, `run_seg7.sh`, `run_cpi.sh`, `run_mulbench.sh`, `run_mathdemo.sh`, `run_mathdisp.sh`, `run_rxsoc.sh`, `run_calc.sh`, `run_ram16.sh`, `run_coremark.sh`. Each ends with a PASS line and a non-zero exit on failure.

Build and program one firmware image on the board:

    bash tools/build_hw_image.sh NAME firmware/SOURCE.c
    vivado -mode batch -source scripts/program.tcl -tclargs build/NAME.bit
    picocom -b 115200 /dev/ttyUSB1

The build script fails closed on Vivado errors, copies the timing and utilization reports to `docs/reports/NAME/`, and restores the default firmware afterwards. Images that need more than 8 KB (the CoreMark port, `firmware/ramtest.c`) are linked with `firmware/link16.ld` and `firmware/start16.S`; `build_hw_image.sh` does not do that yet.

Hardware notes: one micro-USB cable into `PROG UART USB PWR` powers, programs and carries the UART (FT2232H, UART is the second ttyUSB, 115200 8N1). Jumper `PWR SEL` on `USB`, switch `SW16` on.

## Layout

    rtl/            core, decoder, ALU, LSU, RAM, UART TX/RX, seven-segment driver, multiplier, SoC top
    tb/             unit and SoC testbenches
    firmware/       test programs and demos; link.ld/start.S (8 KB), link16.ld/start16.S (16 KB), cm_port/ (CoreMark)
    tools/          run_*.sh gates, checkers, Python ISS, random-program generator, build_hw_image.sh
    tests/          riscv-tests environment
    scripts/        Vivado programming script, test-vector generators
    constraints/    Urbana pin and clock constraints
    third_party/    picorv32 (control SoC), coremark (EEMBC)
    docs/           reports (timing/utilization per build) and media

## Not done

- 100 MHz (the 4-stage core misses by 0.076 ns).
- M extension (multiplies go through the MMIO accelerator, not an instruction).
- A valid CoreMark run on the board.
- Block-RAM memory (LUTRAM is at 43% of its budget at 16 KB, so 32 KB is the practical ceiling).

## Provenance and licences

Code was written with LLM assistance (Qwen for generation, Claude for review) and independently verified with the tests above; all results come from tools run locally. This repository's own code is MIT. `third_party/picorv32` is ISC (YosysHQ). `third_party/coremark` is EEMBC CoreMark under its own licence and acceptable-use terms; CoreMark is a trademark of EEMBC.
