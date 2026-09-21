# RV32I SoC for Tang Nano 9K

[![CI](https://github.com/haibv10/do-an-thiet-ke-he-thong-so/actions/workflows/ci.yml/badge.svg)](https://github.com/haibv10/do-an-thiet-ke-he-thong-so/actions/workflows/ci.yml)

> A 32-bit RISC-V system-on-chip written from scratch in Verilog, running on a
> Gowin GW1NR-9C FPGA.

The core is a five-stage RV32I pipeline with full forwarding, load-use
interlocking and branch flushing. Around it sit on-chip instruction and data
memory plus four peripherals — GPIO, UART, I2C and SPI — all reachable through a
single memory-mapped bus. The CPU has no special instructions for hardware: an
address decoder turns ordinary `lw` and `sw` into peripheral access.

Firmware is written in C, compiled with the standard RISC-V toolchain and linked
into the bitstream as ROM contents.

```c
/* Blink the LED from software. That is the whole driver. */
*(volatile unsigned int *)0x40000000 = 1;
```

---

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Memory map](#memory-map)
- [Getting started](#getting-started)
- [Hardware setup](#hardware-setup)
- [Repository layout](#repository-layout)
- [Verification](#verification)
- [Known limitations](#known-limitations)
- [Documentation](#documentation)

## Features

- **RV32I core** — 38 of the 40 base instructions, five-stage pipeline
- **Hazard handling** — EX/MEM and MEM/WB forwarding, a write-first register
  file bypass, one-cycle load-use stall, two-cycle branch flush
- **Sub-word memory access** — `LB`, `LBU`, `LH`, `LHU`, `LW`, `SB`, `SH`, `SW`
  through a byte-alignment stage
- **Memory-mapped I/O** — one address decoder, six regions, no peripheral-specific
  CPU instructions
- **UART** — 115200 8N1, memory-mapped transmit and 16-byte receive FIFO
- **I2C** — master in both directions, one frame per store, with repeated START
  for register reads
- **SPI** — write-only mode 0 master for an ST7735 128x160 TFT, with chip select,
  data/command and panel reset held in software
- **Firmware** — reads the DS3231 over I2C and draws the date and time on the
  panel from an 8x8 ASCII font in ROM
- **Headless toolflow** — simulation, synthesis, place and route and programming
  all run from the command line

## Architecture

```text
   ┌──────────────┐          ┌────────────────────────────────┐
   │    IMEM      │  instr   │   RV32I CPU — 5-stage pipeline  │
   │  ROM 8 KB    │ ───────► │      IF · ID · EX · MEM · WB    │
   └──────────────┘          └────────────────┬───────────────┘
                                              │ addr · wdata · we_mask
                                              ▼
                              ┌───────────────────────────────┐
                              │        ADDRESS DECODER        │
                              │     selects on addr[31:28]    │
                              └──┬─────┬───────┬───────┬──────┬┘
                                0x2   0x4     0x5     0x6    0x7
                                 ▼     ▼       ▼       ▼      ▼
                            ┌───────┐┌──────┐┌──────┐┌─────┐┌───────┐
                            │ DMEM  ││ GPIO ││ UART ││ I2C ││  SPI  │
                            │RAM 4K ││      ││ 8N1  ││50kHz││mode 0 │
                            └───────┘└──┬───┘└──┬───┘└──┬──┘└───┬───┘
                                        ▼       ▼       ▼       ▼
                                      LED    laptop  DS3231  ST7735
```

Branches resolve in EX, so a taken branch costs two cycles. There is no branch
predictor; the design trades those cycles for a simpler control path.

The reset input passes through its required clock-domain protection before the
design uses it. Reset releases in step with the clock rather than whenever the
contact happens to open.

The ROM has a second read port wired to the same decoder, so loads from region
`0x0` reach `.rodata` and the load image of `.data`. That is what lets the
firmware use string literals and initialised globals.

## Memory map

| `addr[31:28]` | Base | Device | Notes |
|---|---|---|---|
| `0x0` | `0x00000000` | Instruction memory, 8 KB | Fetch, plus read-only data access for `.rodata` and the `.data` load image |
| `0x2` | `0x20000000` | Data memory, 4 KB | Globals and stack |
| `0x4` | `0x40000000` | GPIO | LED output |
| `0x5` | `0x50000000` | UART | 115200 8N1, TX and RX |
| `0x6` | `0x60000000` | I2C | 50 kHz master, read and write |
| `0x7` | `0x70000000` | SPI | ST7735 128x160 TFT, write only |

Per-register details are in [docs/hardware/register_map.md](docs/hardware/register_map.md).

## Getting started

### Prerequisites

| Tool | Used for |
|---|---|
| Icarus Verilog ≥ 11 (`iverilog`, `vvp`) | Running the testbenches |
| — | Also run on every push by [CI](.github/workflows/ci.yml) |
| `riscv64-unknown-elf-gcc` and binutils | Compiling the firmware |
| Gowin EDA V1.9.12.03 | Synthesis, place and route, bitstream |
| `picocom` | Reading UART output from the board |

Every command below is run from the repository root:

```bash
cd /home/haihbv/Desktop/work/fpga/thiet_ke_he_thong_so
```

The Gowin flow needs `GOWIN_ROOT` exported first:

```bash
export GOWIN_ROOT=/home/haihbv/tools/Gowin_V1.9.12.03
```

### Run the test suite

```bash
bash tools/run_tests.sh
```

Runs 33 self-checking testbenches, ending with `firmware_boot_tb`, which boots
the real `sw/firmware.hex` image on the full SoC and decodes its UART output.
Each prints `<name>: PASS`; the script stops at the first failure.

### Build the firmware

```bash
bash tools/build_firmware.sh
```

Compiles `sw/main.c` and `sw/startup.s` into `sw/firmware.hex`. `mem_instruction_rom.v` reads
that file with `$readmemh` at elaboration time, so rebuild the firmware before
building a bitstream whenever the software changes.

### Build the bitstream

```bash
bash tools/build_fpga.sh
```

Runs synthesis, place and route, timing analysis and bitstream generation,
producing `build/gowin/impl/pnr/fpga_project.fs`. The build passes when the
output contains `Timing analysis completed` and `Bitstream generation completed`
with no `ERROR`.

### Program the board

Confirm the JTAG cable sees the device:

```bash
sudo /home/haihbv/tools/Gowin_V1.9.12.03/Programmer/bin/programmer_cli \
  --scan --cable-index 1 --channel 0
```

Write the bitstream into SRAM:

```bash
sudo env GOWIN_ROOT=/home/haihbv/tools/Gowin_V1.9.12.03 bash tools/program_fpga.sh
```

Programming succeeds when the output shows `Programming... 100%` and `Finished.`
SRAM is volatile — the bitstream is lost when the board loses power.

### Watch the UART output

Find the external USB-UART module; do not open either FT2232 interface used by
the Tang Nano board:

```bash
ls -l /dev/serial/by-id/
picocom -b 115200 --flow n /dev/serial/by-id/<external-usb-uart>
```

Press the **S2** reset button on the board to catch the `BOOT` line. Exit with
`Ctrl-A` then `Ctrl-X`.

The shipped firmware prints a banner, brings the ST7735 up and draws three
colour bars, then repeats a liveness line once a second:

```text
BOOT 5A5A5A5A 00000000
TFT INIT
TFT BARS
ALIVE
ALIVE
```

`TFT BARS` without anything on the panel narrows the fault to the backlight or
the wiring rather than the init sequence.

The two words in the banner are a startup self-check: `5A5A5A5A` is a `.data`
global, so it only reads back correctly if `startup.s` copied `.data` out of
ROM, and `00000000` is a `.bss` global, so it only reads back as zero if
`.bss` was cleared.

## Hardware setup

| FPGA pin | Signal | Connects to |
|---|---|---|
| 52 | `clk` | 27 MHz onboard oscillator |
| 3 | `rst_n` | Button S2 |
| 10 | `led_out` | Onboard LED (active low) |
| 34 | `uart_tx_out` | RXD on the external USB-UART module |
| 33 | `uart_rx_in` | TXD on the external USB-UART module |
| 25 | `spi_sck_out` | SCK on the ST7735 module |
| 26 | `spi_mosi_out` | SDA on the ST7735 module |
| 27 | `spi_cs_n_out` | CS on the ST7735 module |
| 28 | `spi_dc_out` | AO on the ST7735 module |
| 29 | `spi_rst_n_out` | RESET on the ST7735 module |
| 31 | `i2c_sda` | SDA on the DS3231 module |
| 32 | `i2c_scl` | SCL on the DS3231 module |

Cross UART TX and RX, and share a ground. The I2C pins are in bank 2 and run
at 3.3 V — do not pull SDA or SCL up to 5 V even if the slave is powered from
5 V.

Power the ST7735 module from 3V3, not the 5V pin: bank 2 drives 3.3 V logic.
Tie its `LED` pin straight to 3V3 — the backlight draws more than the 8 mA the
IO pins are set to drive. Pins 25 through 30 are the only run of bank 2 header
pins with no onboard component on them; 36 through 39 sit next to them but
belong to the TF card slot. Pin 30 is left free for backlight control through a
transistor.

Board-specific pitfalls, including how to tell the external UART node from the
FT2232 JTAG channel, are collected in [docs/bringup.md](docs/bringup.md).

## Repository layout

| Path | Contents |
|---|---|
| `source/` | CPU RTL, peripherals and common modules. `source/cpu/cpu_top.v` is the top module |
| `libs/` | Reusable protocol blocks. Each library keeps its RTL and unit testbench together |
| `constr/` | Pin (`.cst`) and timing (`.sdc`) constraints |
| `sw/` | C firmware, startup code, linker script and the built `firmware.hex` |
| `sim/` | Testbenches for `source/`, one `sim/` directory per `source/` directory; `sim/support/` holds shared fixtures |
| `tools/` | Scripts for firmware, bitstream, programming and tests |
| `docs/` | Design report, register map, bring-up notes, verification results |
| `rules/` | Coding style, commit and branching conventions |
| `build/` | Generated output, not committed |

`libs/i2c/i2c_slave_model.sv` is a behavioural slave used by the I2C
testbenches. It is verification only and is never synthesized.

## Verification

| Layer | Result |
|---|---|
| Simulation | 33 / 33 testbenches pass on Icarus Verilog 12.0 |
| Timing | Fmax 27.678 MHz against a 27 MHz constraint, 0 setup and 0 hold violations. The critical path is the ROM data window through the load formatter, and it moves with the firmware image |
| Resources | Logic 3256 / 8640 (38%), registers 1598 / 6693 (24%), BSRAM 6 / 26 (24%) |
| Hardware | Banner reads `BOOT 5A5A5A5A 00000000`, the ST7735 shows red, green and blue bars and then the date and time from the DS3231, whose oscillator stop flag reads clear and whose time survives reprogramming. The 4392-byte image runs from beyond the old 4 KB ROM boundary. The RX FIFO board protocol passed its 16-byte, overrun and W1C cases when it was run; that firmware has since been retired to make ROM room and the result is kept in the fix log |

Measurements and the logs behind them are in
[docs/verification/rv32i_pipeline.md](docs/verification/rv32i_pipeline.md).

## Known limitations

- **UART RX has no flow control.** Its 16-byte FIFO absorbs short bursts and
  reports overrun, but a sustained stream faster than software can consume
  still loses bytes.
- **ECALL and EBREAK are not implemented.** The core covers 38 of the 40 RV32I
  base instructions; there is no trap or privilege machinery for them to hook into.
- **Timing margin is 12%.** Fmax 30.210 MHz against the 27 MHz oscillator. The
  binding path is the half-cycle memory read into MEM/WB.

Defects found and fixed, each with the evidence behind it, are recorded in
[docs/fix_log.md](docs/fix_log.md).

## Documentation

| Document | Contents |
|---|---|
| [docs/design_report.md](docs/design_report.md) | Full design report |
| [docs/hardware/register_map.md](docs/hardware/register_map.md) | MMIO register reference |
| [docs/bringup.md](docs/bringup.md) | Board bring-up procedure and pitfalls |
| [docs/fix_log.md](docs/fix_log.md) | Defects found, fixes applied and the evidence for each |
| [docs/verification/rv32i_pipeline.md](docs/verification/rv32i_pipeline.md) | Simulation, timing and hardware results |
| [rules/](rules/) | Coding style, commit style, git flow |
| [docs/images/README.md](docs/images/README.md) | What each figure shows, and which ones are not from this project |
