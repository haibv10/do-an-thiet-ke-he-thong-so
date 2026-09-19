# RV32I pipeline verification

## Simulation

Icarus Verilog 11.0 passes twenty-two self-checking tests. Coverage includes ALU and decode operations,
immediate generation, register file read/write/bypass behavior, forwarding priority, load-use hazard
detection, pipeline register reset/stall/flush behavior, branch and JAL flushing, subword memory accesses,
GPIO MMIO, an UART TX frame containing `0x48`, UART RX framing with start/stop validation and LSB-first
assembly, UART MMIO status and read-clear semantics, and a CPU-level echo that drives `0xA5` into the RX pin
and checks that the CPU transmits the same byte back, plus the I2C frame FSM, the PCF8574 LCD write sequence
and the I2C MMIO handshake.

Four tests are CPU-level programs rather than unit tests:

| Testbench | What it proves |
|---|---|
| `cpu_hazard_tb` | RAW dependencies at distance one through four, including a load producer, and the load-use interlock |
| `cpu_auipc_tb` | AUIPC at several program counters, loads out of the ROM window, and that a store into ROM is dropped |
| `uart_hex_cpu_tb` | The `sltiu` plus branch sequence the hex formatter depends on |
| `firmware_boot_tb` | The real `sw/firmware.hex` image booting on the full SoC, decoded off the UART pin |

`firmware_boot_tb` is the end-to-end case. It checks the banner byte by byte:

```text
firmware_boot_tb: PASS (banner "BOOT 5A5A5A5A 00000000")
```

`5A5A5A5A` is a `.data` global and `00000000` a `.bss` global, so the banner passes only if `startup.s`
copied `.data` out of ROM and cleared `.bss`. The digits come from a `.rodata` table, so it also exercises
the ROM data window.

Command:

```bash
bash tools/run_tests.sh
```

## FPGA build

Gowin V1.9.12.03 completes synthesis, placement/routing, timing analysis, and bitstream generation for
`GW1NR-LV9QN88PC6/I5` using the 27 MHz constraint in `constr/fpga_project.sdc`.

Post-route summary:

| Metric | Result |
|---|---:|
| Constraint | 27.000 MHz |
| Actual Fmax | 31.762 MHz |
| Logic levels | 15 |
| Setup violated endpoints | 0 |
| Hold violated endpoints | 0 |
| Setup TNS | 0.000 ns |
| Hold TNS | 0.000 ns |
| Logic | 3343 / 8640 (39%) |
| Registers | 1588 / 6693 (24%) |
| Registers inferred as latch | 0 / 6480 (0%) |
| CLS | 2700 / 4320 (63%) |
| BSRAM | 6 / 26 (24%) |
| I/O ports | 8 / 71 (12%) |

These figures are from the current tree. Zero registers are inferred as latches, confirming the two I2C
FSMs have explicit default states. Raw log: `logs/02-fpga-build.log`.

The board measurements further down predate the fixes in [docs/fix_log.md](../fix_log.md); this bitstream
has not been programmed yet.

The generated SRAM bitstream is `build/gowin/impl/pnr/fpga_project.fs`.

## Hardware

Gowin Programmer detects the Tang Nano 9K as `GW1NR-9C` with ID `0x1100481B`. SRAM programming reaches
100% using the FT2CH JTAG channel. The FT2232 UART interface 1 enumerates as `/dev/ttyUSB1`.

### UART TX

A 115200 baud, 8N1 raw capture of the transmit-only firmware contains an initial `0xff` sample followed by
repeated `0x48` bytes, confirming the UART TX path from CPU MMIO through FPGA pin 34 to the external USB-UART module.

### UART RX

The echo firmware polls `rx_valid`, reads `UART_BASE + 0x08`, transmits the byte back, and drives the LED
from bit 0 of the received value. Measurements use 115200 baud, 8N1, raw mode, no flow control:

| Stimulus | Result |
|---|---|
| Idle, 5 s capture, repeated twice | 0 bytes, no spurious frames |
| Single bytes `41 42 00 ff 55 aa 0f f0 7e` | every byte echoed exactly |
| `ABHello` sent back to back | `41 42 48 65 6c 6c 6f` |
| `ABHello` sent at 20 ms spacing | `41 42 48 65 6c 6c 6f` |
| 16, 64, and 256 random bytes back to back | byte-identical echo |
| 1024 random bytes back to back | 1021 bytes returned, content mismatched |
| `A` then `B`, observing the onboard LED | LED off then on |

The LED result is inverted with respect to the firmware value. The onboard LED on the Tang Nano 9K is
active low, so driving the GPIO pin high turns it off. `A` is `0x41` and writes bit 0 as one, which switches
the LED off; `B` is `0x42` and writes bit 0 as zero, which switches it on. The GPIO register itself follows
the written value, so this is a board level polarity convention rather than a data path fault.

### Known limitation

The receiver holds a single byte and has no FIFO. A new byte overwrites the previous one if software has not
read it yet. At 115200 baud a transmit frame occupies ten bit times, which leaves the polling loop no slack
against a host sending continuously, so the design slips and drops bytes on sustained streams. Bursts up to
256 bytes are lossless; a 1024 byte burst loses roughly 0.3% of the stream. Lossless sustained streaming
requires an RX FIFO, which this feature deliberately does not implement.

### I2C and LCD

The scan firmware sweeps `0x20-0x27` and `0x38-0x3f`, reports the acknowledging address over UART and writes
`HELLO FPGA` to the display. After the ACK sampling phase was corrected, the capture repeats `I2C 21` byte for
byte and the 20x4 LCD shows the string, so `0x21` is the real PCF8574 address on this backpack rather than the
more common `0x27`.

| Stimulus | Result | Evidence |
|---|---|---|
| Reset with no device wired | repeated `I2C NACK` | `logs/06-fault-i2c-nack.log` |
| Reset, firmware reading `.rodata` | `I2C ` followed by two `0x00` bytes | `logs/07-fault-rodata-null.log` |
| Reset, hex formatter using the A-F branch | `I2C 2>` instead of `I2C 27` | `logs/08-fault-hex-branch.log` |
| Reset, current firmware | `I2C 21` repeated, LCD shows `HELLO FPGA` | `logs/05-board-uart.log` |

Rows two and three are CPU faults, not UART faults, and both are now fixed — see
[docs/fix_log.md](../fix_log.md) findings 6 and 1. In row three `'0' + 14` is `0x3e` and `'A' - 10 + 7` is also
`0x3e`, so the low nibble took the A-F branch while the high nibble of the same call took the correct one.
The hex formatter now uses a `.rodata` lookup table instead of that branch.

### Bring-up procedure

Recorded separately in [docs/bringup.md](../bringup.md): always reprogram before measuring, how to tell the
external USB-UART node from the FT2232 JTAG channel, restoring `ftdi_sio`, and the I2C voltage constraint.
