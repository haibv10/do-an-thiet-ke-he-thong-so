# RV32I SoC for Tang Nano 9K

> A 32-bit RISC-V system-on-chip written from scratch in Verilog, running on a
> Gowin GW1NR-9C FPGA.

The core is a five-stage RV32I pipeline with full forwarding, load-use
interlocking and branch flushing. Around it sit on-chip instruction and data
memory plus three peripherals — GPIO, UART and I2C — all reachable through a
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

- **RV32I core** — 36 of the 40 base instructions, five-stage pipeline
- **Hazard handling** — EX/MEM and MEM/WB forwarding, one-cycle load-use stall,
  two-cycle branch flush
- **Sub-word memory access** — `LB`, `LBU`, `LH`, `LHU`, `LW`, `SB`, `SH`, `SW`
  through a byte-alignment stage
- **Memory-mapped I/O** — one address decoder, four regions, no peripheral-specific
  CPU instructions
- **UART** — 115200 8N1, transmit and receive, both memory mapped
- **I2C** — bit-banged master driving a 20x4 HD44780 LCD over a PCF8574 backpack
- **Headless toolflow** — simulation, synthesis, place and route and programming
  all run from the command line

## Architecture

```text
   ┌──────────────┐          ┌────────────────────────────────┐
   │    IMEM      │  instr   │   RV32I CPU — 5-stage pipeline  │
   │  ROM 4 KB    │ ───────► │      IF · ID · EX · MEM · WB    │
   └──────────────┘          └────────────────┬───────────────┘
                                              │ addr · wdata · we_mask
                                              ▼
                              ┌───────────────────────────────┐
                              │        ADDRESS DECODER        │
                              │     selects on addr[31:28]    │
                              └──┬────────┬────────┬───────┬──┘
                                0x2      0x4      0x5     0x6
                                 ▼        ▼        ▼       ▼
                            ┌────────┐┌──────┐┌──────┐┌────────┐
                            │  DMEM  ││ GPIO ││ UART ││  I2C   │
                            │ RAM 4K ││      ││ 8N1  ││        │
                            └────────┘└──┬───┘└──┬───┘└───┬────┘
                                         ▼       ▼        ▼
                                    LED, button laptop  20x4 LCD
                                                        (PCF8574)
```

Branches resolve in EX, so a taken branch costs two cycles. There is no branch
predictor; the design trades those cycles for a simpler control path.

## Memory map

| `addr[31:28]` | Base | Device | Notes |
|---|---|---|---|
| `0x0` | `0x00000000` | Instruction memory | Fetch stage only — not readable over the data bus |
| `0x2` | `0x20000000` | Data memory, 4 KB | Globals and stack |
| `0x4` | `0x40000000` | GPIO | LED output, button input |
| `0x5` | `0x50000000` | UART | 115200 8N1, TX and RX |
| `0x6` | `0x60000000` | I2C | 20x4 LCD through a PCF8574 |

Per-register details are in [docs/hardware/register_map.md](docs/hardware/register_map.md).

## Getting started

### Prerequisites

| Tool | Used for |
|---|---|
| Icarus Verilog ≥ 11 (`iverilog`, `vvp`) | Running the testbenches |
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

Runs 18 self-checking testbenches. Each prints `<name>: PASS`; the script stops
at the first failure.

### Build the firmware

```bash
bash tools/build_firmware.sh
```

Compiles `sw/main.c` and `sw/startup.s` into `sw/firmware.hex`. `imem.v` reads
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

```bash
picocom -b 115200 --flow n /dev/ttyUSB0
```

Press the **S2** reset button on the board to catch the `BOOT` line. Exit with
`Ctrl-A` then `Ctrl-X`.

The shipped firmware sends `BOOT`, scans `0x20-0x27` and `0x38-0x3f` for a
PCF8574, prints the address it finds and writes `HELLO FPGA` to the LCD:

```text
BOOT
I2C 21
I2C 21
```

## Hardware setup

| FPGA pin | Signal | Connects to |
|---|---|---|
| 52 | `clk` | 27 MHz onboard oscillator |
| 3 | `rst_n` | Button S2 |
| 4 | `btn_in` | Button S1 |
| 10 | `led_out` | Onboard LED (active low) |
| 34 | `uart_tx_out` | RXD on the external USB-UART module |
| 33 | `uart_rx_in` | TXD on the external USB-UART module |
| 31 | `i2c_sda` | SDA on the PCF8574 backpack |
| 32 | `i2c_scl` | SCL on the PCF8574 backpack |

Cross UART TX and RX, and share a ground. The I2C bus runs at 3.3 V — do not
pull SDA or SCL up to 5 V even if the LCD itself is powered from 5 V.

Board-specific pitfalls, including how to tell the external UART node from the
FT2232 JTAG channel, are collected in [docs/bringup.md](docs/bringup.md).

## Repository layout

| Path | Contents |
|---|---|
| `src/` | SoC RTL. `cpu_top.v` is the top module |
| `constr/` | Pin (`.cst`) and timing (`.sdc`) constraints |
| `sw/` | C firmware, startup code, linker script and the built `firmware.hex` |
| `tb/` | Self-checking SystemVerilog testbenches; `tb/support/` holds helpers |
| `tools/` | Scripts for firmware, bitstream, programming and tests |
| `docs/` | Design report, register map, bring-up notes, verification results |
| `logs/` | Curated verification evidence — see [logs/README.md](logs/README.md) |
| `rules/` | Coding style, commit and branching conventions |
| `build/` | Generated output, not committed |

`src/lcd_display.v` is a standalone 20x4 LCD sequencer kept for reference. It is
**not** instantiated by `cpu_top` and is not synthesized.

## Verification

| Layer | Result |
|---|---|
| Simulation | 18 / 18 testbenches pass on Icarus Verilog 11.0 |
| Timing | Fmax 34.937 MHz against a 27 MHz constraint, 0 setup and 0 hold violations |
| Resources | Logic 3167 / 8640 (37%), registers 1587 / 6693 (24%), BSRAM 5 / 26 (20%) |
| Hardware | LCD displays `HELLO FPGA`, UART reports the PCF8574 at `0x21` |

Measurements and the logs behind them are in
[docs/verification/rv32i_pipeline.md](docs/verification/rv32i_pipeline.md).

## Known limitations

- **AUIPC is not implemented.** Opcode `0010111` decodes silently to a NOP.
- **ROM is not readable over the data bus.** `.rodata` — string literals and
  lookup tables — reads back as zero.
- **`.data` and `.bss` are not initialised.** `startup.s` sets the stack pointer
  and jumps to `main` without copying or zeroing.
- **UART RX holds a single byte.** There is no FIFO and no overrun flag; a new
  byte overwrites the previous one if software has not read it.
- **A RAW hazard three instructions apart reads a stale register.** The register
  file has no WB-to-ID bypass and the forwarding unit only covers distances one
  and two.
- **I2C does not emit a compliant STOP condition,** and the NACK path skips the
  ninth SCL pulse.

## Documentation

| Document | Contents |
|---|---|
| [docs/design_report.md](docs/design_report.md) | Full design report |
| [docs/hardware/register_map.md](docs/hardware/register_map.md) | MMIO register reference |
| [docs/bringup.md](docs/bringup.md) | Board bring-up procedure and pitfalls |
| [docs/verification/rv32i_pipeline.md](docs/verification/rv32i_pipeline.md) | Simulation, timing and hardware results |
| [rules/](rules/) | Coding style, commit style, git flow |
