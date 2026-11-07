# FPGA-Based RISC-V SoC for Environmental Monitoring

A Tang Nano 9K SoC with a five-stage RV32I processor, 8 KiB instruction ROM
and 4 KiB data RAM. Firmware reads DHT11 temperature/humidity, MQ-5 output
voltage through an ADS1115, and DS3231 date/time, then displays readings on
an ST7735 128x160 TFT. UART provides status output and RTC setup.

MQ-5 levels use voltage thresholds, not calibrated gas concentrations in ppm.

## Source layout

```text
source/
├── soc_top.v          SoC integration and FPGA top module
├── cpu/               Core, pipeline, forwarding and hazards
├── bus/               Address decoder
├── memory/            Instruction ROM and data RAM
├── common/            Clock enable and reset synchronizer
└── peripheral/        GPIO, UART, I2C, SPI and DHT11 controllers/MMIO
sw/
├── startup/           Startup assembly and linker.ld
├── hal/               MMIO access
├── drivers/           DS3231, MQ-5/ADS1115 and ST7735
├── graphics/          ASCII font
├── app/               Main loop and display layout
└── common/            Delay utility
tb/                    CPU, bus, memory, common and peripheral unit tests
├── integration/       Full-SoC execution and firmware startup tests
└── support/           I2C slave model, ROM fixture and VCD helper
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

The CPU uses IF/ID/EX/MEM/WB, forwarding, load-use interlocking and branch/jump
flushing. Peripherals use ordinary loads/stores through MMIO. The system runs
in one 27 MHz clock domain; reset asserts asynchronously and releases
synchronously. I2C runs at 50 kHz; SPI uses mode 0, MSB first, at 6.75 MHz.

| Base address | Device | Purpose |
|---|---|---|
| `0x00000000` | Instruction ROM | Instructions, `.rodata` and `.data` load image |
| `0x20000000` | Data RAM | Globals, `.bss` and stack |
| `0x40000000` | GPIO | Onboard LED |
| `0x50000000` | UART | 115200 8N1 transmit and 16-byte receive FIFO |
| `0x60000000` | I2C | DS3231 RTC and ADS1115 transactions at 50 kHz |
| `0x70000000` | SPI | Write-only ST7735 transfers at 6.75 MHz |
| `0x80000000` | DHT11 | Start, status and whole-number temperature/humidity data |


ROM has separate instruction and data read ports. ROM/RAM reads register on
the falling edge before pipeline capture on the rising edge. Startup copies
`.data` from ROM to RAM, clears `.bss` and sets the stack to the top of RAM.
If memory sizes change, update RTL depth/indexing, `sw/startup/linker.ld`,
`tools/make_hex.py` and the affected tests together.

Firmware uses `-Os`; `delay_loop` retains `-O1` because its timing depends on
the generated instruction sequence. Keep LTO disabled unless delays are
revalidated. `rom/firmware.hex` is committed because simulation and synthesis
load it during elaboration.

## Toolchain and build

On Ubuntu, install the command-line dependencies and install/license Gowin
EDA V1.9.12.03 separately:

```bash
sudo apt update
sudo apt install -y build-essential python3 gcc-riscv64-unknown-elf iverilog openfpgaloader picocom
export GOWIN_ROOT=/path/to/Gowin
```

Run from the repository root. `GOWIN_ROOT` must contain `IDE/bin/gw_sh` and,
for SRAM programming, `Programmer/bin/programmer_cli`. There is no default
installation path. Override the compiler prefix with `RISCV_TOOL_PREFIX` if
needed; the default is `riscv64-unknown-elf`.

| Command | Result |
|---|---|
| `make test` | Run all 33 RTL testbenches; output under `build/sim/` |
| `make firmware` | Compile C/assembly and update `rom/firmware.hex` |
| `make fpga` | Build firmware and synthesize/place/route the FPGA |
| `make program` | Build and program volatile FPGA SRAM with Gowin |
| `make flash` | Build and program persistent Flash with openFPGALoader |

`make test` expects 33 `PASS` lines. It covers core logic, protocol controllers,
SoC integration and startup; it does not validate sensor behavior on hardware.
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
