# FPGA-Based RISC-V SoC

A Tang Nano 9K SoC with a five-stage RV32I processor, 16 KiB instruction ROM
and 8 KiB data RAM. Bare-metal firmware accesses peripherals through MMIO.

The application reads DHT11 temperature/humidity, MQ-5 output voltage through
an ADS1115 and DS3231 date/time, then shows them on an ST7735 128x160 TFT.
UART provides status output and RTC setup. MQ-5 levels are voltage thresholds,
not calibrated gas concentrations.

## Source layout

```text
source/
├── soc_top.v          SoC integration and FPGA top module
├── cpu/               Five-stage pipeline, forwarding and hazard logic
├── bus/               Address decoder
├── memory/            Instruction ROM and data RAM
├── common/            Clock enable and reset synchronizer
└── peripheral/        GPIO, UART, I2C, SPI and DHT11 controllers
sw/
├── startup/           Startup assembly and linker script
├── hal/               MMIO register access
├── drivers/           DS3231, MQ-5/ADS1115 and ST7735
├── graphics/          UI renderer, generated font/icon masks and licenses
├── app/               Main loop and dashboard layout
└── common/            Delay loop
tb/                    Core CPU, SoC and peripheral testbenches
constr/                Pin and timing constraints
rom/                   Committed firmware.hex
tools/                 Build, test, programming and RTC sync scripts
```

## Hardware and wiring

Target: GW1NR-LV9QN88PC6/I5, onboard 27 MHz clock. All modules use 3.3 V logic
and share GND. UART TX/RX cross to the adapter RXD/TXD.

| Tang Nano 9K pin | RTL signal | Connection |
|---|---|---|
| 52 | `clk` | Onboard 27 MHz oscillator |
| 3 | `rst_n` | Onboard S2 reset button |
| 10 | `led_out` | Onboard active-low LED |
| 34 | `uart_tx_out` | RXD on the USB-UART |
| 33 | `uart_rx_in` | TXD on the USB-UART |
| 31 | `i2c_sda` | SDA on DS3231 and ADS1115 |
| 32 | `i2c_scl` | SCL on DS3231 and ADS1115 |
| 25 | `spi_sck_out` | SCK on the ST7735 |
| 26 | `spi_mosi_out` | SDA/MOSI on the ST7735 |
| 27 | `spi_cs_n_out` | CS on the ST7735 |
| 28 | `spi_dc_out` | A0/DC on the ST7735 |
| 29 | `spi_rst_n_out` | RESET on the ST7735 |
| 30 | `dht11_data` | DHT11 DATA, 4.7 kΩ pull-up to 3.3 V |
| 3V3 | — | VCC of DS3231, ST7735 (incl. backlight), ADS1115, DHT11; pull-ups |
| GND | — | Common ground |

ADS1115 uses address `0x48` (ADDR to GND) and AIN0. Connect MQ-5 AO through a
10 kΩ upper / 20 kΩ lower divider; firmware compensates for it. Never connect
the 5 V AO directly to the FPGA or the ADC input.

## Architecture and memory map

The CPU implements IF/ID/EX/MEM/WB with forwarding, load-use stall and
branch/jump flush. Instruction and data ports have fixed latency with no
wait handshake: ROM/RAM reads register on the falling edge and are captured on
the rising edge. Everything runs in one 27 MHz clock domain; reset asserts
asynchronously and releases synchronously. I2C runs at 100 kHz; SPI uses
mode 0, MSB first, 13.5 MHz.

| Address range | Device | Purpose |
|---|---|---|
| `0x00000000–0x00003FFF` | Instruction ROM | Code, `.rodata`, `.data` load image |
| `0x20000000–0x20001FFF` | Data RAM | `.data`, `.bss`, stack |
| `0x40000000–0x40000003` | GPIO | Onboard LED |
| `0x50000000–0x5000000F` | UART | TX, status, RX, overrun clear |
| `0x60000000–0x6000000B` | I2C | Frame command, status, received data |
| `0x70000000–0x7000000B` | SPI | TX, status, panel control pins |
| `0x80000000–0x80000007` | DHT11 | Start/status, measurement |

Peripheral registers are word-aligned; word stores and low-byte stores are
supported. Unmapped reads return zero, unmapped writes are ignored, and there
are no access-fault traps. The DHT11 controller in RTL handles acquisition,
timeout and checksum.

Startup copies `.data` from ROM to RAM, clears `.bss` and sets the stack to the
top of RAM. Memory size is hard-coded in several places that must agree: the
RTL memory depths (`source/memory/`), the decoder windows
(`source/bus/cpu_address_decoder.v`), the ROM fetch limit in `source/soc_top.v`,
`sw/startup/linker.ld` and `ROM_WORDS` in `tools/make_hex.py`.

## Toolchain and build

```bash
sudo apt install -y build-essential python3 gcc-riscv64-unknown-elf iverilog openfpgaloader picocom
export GOWIN_ROOT=/path/to/Gowin   # Gowin EDA V1.9.12.03, contains IDE/bin/gw_sh
```

| Command | Result |
|---|---|
| `make firmware` | Compile firmware, update `rom/firmware.hex`, print ROM/RAM usage |
| `make test` | Run the core RTL testbenches (iverilog) |
| `make fpga` | Build firmware and synthesize/place/route |
| `make program` | Program volatile FPGA SRAM (Gowin `programmer_cli`) |
| `make flash` | Program persistent Flash (openFPGALoader) |
| `make clean` | Remove `build/` |

The bitstream is `build/gowin/impl/pnr/fpga_project.fs`. Close the serial
console before programming. Flash JTAG frequency defaults to 1 MHz; override
with `make flash FLASH_FREQ=500000`. Override the compiler prefix with
`RISCV_TOOL_PREFIX` (default `riscv64-unknown-elf`).

## Core testbenches

`make test` runs eight happy-path iverilog testbenches: each drives the normal
use case once and checks the result. Each prints `<name>: PASS` or stops with
`$fatal` on the first mismatch. Output goes to `build/sim/`. Run it after
changing RTL, before programming the board.

| Testbench | Checks |
|---|---|
| `tb/cpu/cpu_top_tb.sv` | Standalone CPU: forwarding, store/load and load-use stall |
| `tb/integration/cpu_isa_tb.sv` | Each remaining RV32I instruction once in the SoC: ALU, shifts, compares, byte/halfword loads/stores, all branches, AUIPC/JALR, x0 |
| `tb/integration/soc_top_tb.sv` | CPU turns the LED on, sends `H` over UART and echoes a received byte |
| `tb/integration/cpu_firmware_boot_tb.sv` | Runs `rom/firmware.hex`; expects `BOOT OK` (startup copied `.data` and cleared `.bss`) |
| `tb/peripheral/uart/uart_mmio_tb.sv` | UART registers: send one byte, receive one byte and read it |
| `tb/peripheral/i2c/i2c_master_tb.sv` | Write a register on a slave model, then read it back with repeated START |
| `tb/peripheral/spi/spi_master_tb.sv` | Send one byte in mode 0 at `CLK_DIV=1` (the SoC setting) |
| `tb/peripheral/dht11/dht11_mmio_tb.sv` | Read one humidity/temperature frame from a sensor model |

`tb/support/` holds the I2C slave and DHT11 sensor models used by these tests.
Test bytes are not bit-symmetric, so a wrong bit order fails. The boot test
depends on the committed ROM image, so run `make firmware` before `make test`
after changing firmware. Error cases (noise, timeouts, NACK) are not tested;
these tests check RTL behaviour only, not board wiring or real sensors.

## Operation

Open the UART at 115200 8N1 without flow control, then press S2:

```bash
picocom -b 115200 --flow n /dev/ttyUSB0
```

Startup prints `BOOT OK` once `.data`/`.bss` initialization is verified
(otherwise `BOOT FAIL` with the observed values), then `RTC OK` and the time
each second. `RTC TIME LOST` means the DS3231 oscillator stopped, e.g. after
losing its backup battery; set the time as below. The display shows `--` for
invalid DHT11 readings, `NO ADC` if the ADC fails, and `NOT SET` if the RTC lost
its time. Press `P` to switch between the dashboard and the 60-sample gas history.

MQ-5 thresholds are in `sw/drivers/mq5_sensor.h`: `CLEAN` below 1500 mV,
`WARN` from 1500 mV, `DANGER` from 2500 mV. Calibrate them for the actual module.

### RTC setup

Exit picocom (`Ctrl-A`, `Ctrl-X`) and sync the RTC from the laptop clock
(needs `python3-serial`):

```bash
python3 tools/sync_rtc.py --port /dev/ttyUSB0
```

It sends the laptop time in `Asia/Ho_Chi_Minh` (change with `--timezone`) and
checks the `RTC SET OK` reply and readback. To set a time manually, send
`WYYMMDDhhmmss`, for example 2026-11-08 12:30:00:

```bash
stty -F /dev/ttyUSB0 115200 raw -echo
printf 'W261108123000' > /dev/ttyUSB0
```

## UI assets

Font and icon masks in `sw/graphics/ui_assets.*` are generated and committed, so
normal builds need no extra tools. To regenerate, install `fonts-lato`,
`python3-pil`, `python3-gi`, `python3-cairo` and `gir1.2-rsvg-2.0`, then run
`python3 tools/generate_ui_assets.py`. Lato and Lucide licenses are in
`sw/graphics/licenses/`.

## Limitations

No multiply/divide, floating point, cache, interrupts or OS. `ECALL`/`EBREAK`
are not implemented; `FENCE` is a no-op. The ST7735 interface is write-only.
The RTC uses 24-hour mode and years 2000–2099. UART has a 16-byte RX FIFO and
no flow control.

## License

MIT License. See [LICENSE](LICENSE).
