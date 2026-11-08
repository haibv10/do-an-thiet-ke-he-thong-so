# FPGA-Based RISC-V SoC

A Tang Nano 9K SoC with a five-stage RV32I processor, 8 KiB instruction ROM
and 4 KiB data RAM. The CPU executes bare-metal firmware and accesses peripheral
registers through MMIO. Environmental monitoring is the integrated application;
a separate minimal firmware exercises RAM, GPIO, UART, I2C and SPI.

The environmental firmware reads DHT11 temperature/humidity, MQ-5 output
voltage through an ADS1115, and DS3231 date/time, then displays readings on
an ST7735 128x160 TFT. UART provides status output and RTC setup.

MQ-5 levels use voltage thresholds, not calibrated gas concentrations in ppm.

## Source layout

```text
source/
├── soc_top.v          SoC integration and FPGA top module
├── cpu/               cpu_top, core, pipeline, forwarding and hazards
├── bus/               Address decoder
├── memory/            Instruction ROM and data RAM
├── common/            Clock enable and reset synchronizer
└── peripheral/        GPIO, UART, I2C, SPI and DHT11 controllers/MMIO
sw/
├── startup/           Startup assembly and linker.ld
├── hal/               MMIO access
├── drivers/           DS3231, MQ-5/ADS1115 and ST7735
├── graphics/          ASCII font
├── app/               Environmental app, MMIO demo and display layout
└── common/            Delay utility
tb/                    CPU, bus, memory, common and peripheral unit tests
├── firmware/          Native HAL timeout and memory-report tests
├── integration/       Full-SoC execution and firmware startup tests
└── support/           I2C/DHT11 models, ROM fixture and VCD helper
constr/                Pin and timing constraints
rom/                   Committed firmware.hex
tools/                 Build, test and programming scripts
build/                 Generated output, ignored by Git
```

`fpga_project.gprj` is the Gowin IDE project. The command-line flow uses the
Makefile and `tools/build_gowin.tcl`.

## Hardware and wiring

Target: GW1NR-LV9QN88PC6/I5, onboard 27 MHz clock. External modules share GND.
Use 3.3 V logic and pull-ups; the TFT backlight is powered from 3.3 V rather
than an FPGA I/O. UART TX/RX cross to adapter RXD/TXD.

| Tang Nano 9K pin | RTL signal | Connection |
|---|---|---|
| 52 | `clk` | Onboard 27 MHz oscillator |
| 3 | `rst_n` | Onboard S2 reset button |
| 10 | `led_out` | Onboard active-low LED |
| 34 | `uart_tx_out` | RXD on the external USB-UART |
| 33 | `uart_rx_in` | TXD on the external USB-UART |
| 31 | `i2c_sda` | Shared SDA on DS3231 and ADS1115 |
| 32 | `i2c_scl` | Shared SCL on DS3231 and ADS1115 |
| 25 | `spi_sck_out` | SCK on the ST7735 |
| 26 | `spi_mosi_out` | SDA or MOSI on the ST7735 |
| 27 | `spi_cs_n_out` | CS on the ST7735 |
| 28 | `spi_dc_out` | AO or DC on the ST7735 |
| 29 | `spi_rst_n_out` | RESET on the ST7735 |
| 30 | `dht11_data` | DHT11 DATA, with 4.7 kΩ pull-up to 3.3 V |
| 3V3 | — | DS3231, ST7735, ADS1115 and DHT11 VCC; pull-ups |
| GND | — | DS3231, ST7735, ADS1115, DHT11 and USB-UART ground |

ADS1115 uses address `0x48` (ADDR to GND) and AIN0. Connect MQ-5 AO through a
10 kΩ upper / 20 kΩ lower divider; firmware compensates for this divider.
Power the MQ-5 module as specified by its board. Do not connect its 5 V AO
directly to the FPGA or 3.3 V ADC input. DHT11 DATA needs a 4.7 kΩ pull-up
to 3.3 V.

## Architecture and memory map

`source/cpu/cpu_top.v` contains the processor. `soc_top.v` connects its instruction
and data ports to ROM, RAM, the address decoder and peripheral controllers.
The CPU ports have fixed latency and no ready/wait handshake: instruction and
RAM/ROM data reads settle on the falling edge for capture on the rising edge.
A slower memory would require extending this interface and CPU stall logic.

The CPU uses IF/ID/EX/MEM/WB, forwarding, load-use interlocking and branch/jump
flushing. Peripherals use ordinary loads/stores through MMIO. The system runs
in one 27 MHz clock domain; reset asserts asynchronously and releases
synchronously. I2C runs at 50 kHz; SPI uses mode 0, MSB first, at 6.75 MHz.

| Address range (inclusive) | Device | Purpose |
|---|---|---|
| `0x00000000–0x00001FFF` | Instruction ROM | Instructions, `.rodata` and `.data` load image |
| `0x20000000–0x20000FFF` | Data RAM | Globals, `.bss` and stack |
| `0x40000000–0x40000003` | GPIO | Onboard LED |
| `0x50000000–0x5000000F` | UART | TX, status, RX and overrun clear |
| `0x60000000–0x6000000B` | I2C | Frame command, status and received data |
| `0x70000000–0x7000000B` | SPI | TX, status and panel control pins |
| `0x80000000–0x80000007` | DHT11 | Start/status and measurement |

Peripheral register addresses must be word-aligned. Full-word accesses and
stores to the low byte at a register address are supported. Unsupported
register operations have no effect. Unmapped reads return zero and unmapped
writes are ignored; invalid UART addresses do not pop its RX FIFO. Fetches
outside the 8 KiB ROM return zero. There are no access-fault traps.

The DHT11 uses its own single-wire protocol. Its MMIO registers address the
controller inside the FPGA, which handles acquisition, timeout and checksum.

ROM has separate instruction and data read ports. ROM/RAM reads register on
the falling edge before pipeline capture on the rising edge. Startup copies
`.data` from ROM to RAM, clears `.bss` and sets the stack to the top of RAM.
Memory capacity is defined by RTL depth/indexing, `sw/startup/linker.ld`
and the HEX image depth in `tools/make_hex.py`.

Firmware uses `-Os`; `delay_loop` retains `-O1` because its timing depends on
the generated instruction sequence. LTO is disabled. Simulation and synthesis
load `rom/firmware.hex` during elaboration.

## Toolchain and build

On Ubuntu, install the command-line dependencies and install/license Gowin
EDA V1.9.12.03 separately:

```bash
sudo apt update
sudo apt install -y build-essential python3 gcc-riscv64-unknown-elf iverilog openfpgaloader picocom
export GOWIN_ROOT=/path/to/Gowin
```

Run from the repository root. `GOWIN_ROOT` must contain `IDE/bin/gw_sh` and,
for SRAM programming, `Programmer/bin/programmer_cli`.
Override the compiler prefix with `RISCV_TOOL_PREFIX` if
needed; the default is `riscv64-unknown-elf`.

| Command | Result |
|---|---|
| `make clean` | Remove the entire `build/` directory |
| `make test` | Run 39 RTL checks across 37 testbenches; output under `build/sim/` |
| `make test-firmware` | Build both apps; test HAL timeouts and execute the MMIO demo on the simulated CPU |
| `make demo` | Build minimal firmware under `build/demo/`, preserving `rom/firmware.hex` |
| `make firmware` | Compile C/assembly and update `rom/firmware.hex` |
| `make fpga` | Build firmware and synthesize/place/route the FPGA |
| `make program` | Build and program volatile FPGA SRAM with Gowin |
| `make flash` | Build and program persistent Flash with openFPGALoader |

`make test` expects 39 `PASS` lines. It covers the standalone CPU, core logic,
protocol controllers, address boundaries, MMIO side effects, SoC integration
and startup. SPI timing is checked with clock dividers 1, 2 and 3. DHT11 tests
cover valid frames, checksum failure, no response, commands while busy,
recovery and CPU reads through MMIO. These tests do not validate board hardware.
`make test-firmware` additionally requires a native C compiler and the RISC-V
toolchain. Its native test maps fake MMIO pages to exercise stuck-BUSY timeouts;
its RTL test runs the compiled demo with an I2C RTC model and checks RAM, GPIO,
SPI output and UART echo.
A short-ROM fixture intentionally produces a `$readmemh` warning in the ROM
test, which checks that unused words read as zero.

The bitstream is `build/gowin/impl/pnr/fpga_project.fs`. SRAM configuration is
lost at power-off; Flash configuration persists. Close the serial console
before programming. The Makefile uses `sudo` for device access. Flash JTAG
frequency defaults to 1 MHz; override with `make flash FLASH_FREQ=500000`.
After Flash programming, power-cycle the board to check automatic boot.

For optional waveforms, install `gtkwave`, compile the desired testbench with
`tb/support/dump_vcd.sv` as a second top module (`-s dump_vcd`), and run with
`+vcd=build/sim/wave.vcd`.

## Memory usage and minimal demo

Every firmware build writes `memory_usage.txt`, `firmware.map`, `firmware.symbols`,
`firmware.asm` and GCC `.su` stack-frame files to its build directory. The report
shows ROM image bytes, static RAM, remaining RAM and a conservative direct-call
stack estimate from `main`. The estimate sums GCC frames along linked call paths,
including tail calls. Indirect calls, recursion or missing frame information
make the estimate unavailable. This is not a runtime stack high-water measurement.
ROM/RAM capacities remain 8 KiB/4 KiB; these are deployment choices, not RV32I
requirements. FPGA resource utilization and timing must be checked separately
in the Gowin synthesis and place-and-route reports under `build/gowin/impl/`.

```bash
make demo
make test-firmware
make fpga APP=demo GOWIN_ROOT=/path/to/Gowin
```

The demo writes and reads a small RAM array, writes GPIO, reads DS3231 registers
through I2C, sends one ST7735 NOP byte through SPI, then echoes UART input.
Commands `r`, `s` and `l` repeat the RTC read, repeat the SPI transfer and toggle
the LED. `SPI TX OK` confirms controller completion; the write-only interface
cannot confirm that a panel received the byte. No DHT11 or MQ-5 is needed.
A missing RTC produces `I2C NACK/TIMEOUT` and execution continues.

`make program APP=demo` or `make flash APP=demo` builds and programs the demo.
The default `APP=environment` selects the environmental firmware. Standalone
`make demo` leaves the committed environmental ROM image untouched. Gowin builds
select the image through the generated `build/gowin/rom` symlink; both apps use
the same output bitstream path.

HAL polling uses a bounded iteration budget, not a millisecond deadline.
UART output returns failure on timeout; I2C returns failure on NACK or timeout.
SPI returns failure and latches an error until `spi_clear_error()` is called;
the environmental application reports the display error once over UART. Clearing
the software error does not reset the hardware controller.

## Source formatting

```bash
make format
make format-check
```

The first command formats RTL (`source/**/*.v`, `tb/**/*.sv`), C/header files
(`sw/` and `tb/firmware/`) and shell scripts (`tools/*.sh`). The check command reports differences
without modifying files. HEX images, constraints, linker/assembly, Python and
Tcl files are outside the formatter scope.

Formatting uses two-space indentation and a 100-column target for RTL/C.
Makefile recipes retain tabs. Editor defaults are in `.editorconfig`; formatter
settings are in `.clang-format` and `.verible-format.flags`.

Install [Verible](https://github.com/chipsalliance/verible/releases),
[clang-format](https://clang.llvm.org/docs/ClangFormat.html) and
[shfmt](https://github.com/mvdan/sh/releases). Formatter versions:
Verible `v0.0-4298-g085eef05`, clang-format `21.1.8` and shfmt `v3.14.1`.
Use matching versions for reproducible formatting. Tools are resolved from
`PATH`, with a fallback to `build/format-tools/bin/` for project-local binaries.
Explicit executable paths can be supplied through `VERIBLE_FORMAT`,
`CLANG_FORMAT` and `SHFMT`.

## Operation and RTC setup

DHT11 acquisition and checksum validation run in RTL; firmware starts readings
about every two seconds. MQ-5 voltage levels are defined in
`sw/drivers/mq5_sensor.h`: `CLEAN` below 1500 mV, `WARN` from 1500 mV and
`DANGER` from 2500 mV. These thresholds need calibration for the actual module.
The display shows `--` for invalid DHT11 readings and `NO ADC` if ADC access
fails.

Open the USB-UART at 115200 8N1, without flow control, and press S2:

```bash
picocom -b 115200 --flow n /dev/ttyUSB0
```

Startup prints `BOOT 5A5A5A5A 00000000` to check `.data`/`.bss` initialization.
RTC status and time follow. An oscillator-stop flag or invalid calendar value
causes the display to show `NOT SET`.

Exit picocom with `Ctrl-A`, then `Ctrl-X`. Send `WYYMMDDhhmmss` to set the RTC;
for example, 2026-11-08 12:30:00:

```bash
stty -F /dev/ttyUSB0 115200 raw -echo
printf 'W261108123000' > /dev/ttyUSB0
```

Use the actual adapter device path. Successful setup replies `RTC SET OK`;
invalid dates return `RTC SET RANGE`.

## Limitations

The core has no multiply/divide, floating point, cache, virtual memory or OS.
`ECALL`/`EBREAK` are not implemented; `FENCE` acts as an ordering no-op in this
in-order design without a cache or write buffer. The ST7735 interface is
write-only. RTC firmware uses 24-hour mode and years 2000–2099. UART has a
16-byte RX FIFO and no hardware flow control.

## License

MIT License. See [LICENSE](LICENSE).
