# RV32I pipeline verification

## Simulation

Icarus Verilog 11.0 passes twelve self-checking tests. Coverage includes ALU and decode operations, immediate
generation, forwarding priority, load-use hazard detection, pipeline register reset/stall/flush behavior,
branch and JAL flushing, subword memory accesses, GPIO MMIO, an UART TX frame containing `0x48`, UART RX
framing with start/stop validation and LSB-first assembly, UART MMIO status and read-clear semantics, and a
CPU-level echo that drives `0xA5` into the RX pin and checks that the CPU transmits the same byte back.

Command:

```bash
bash tools/run_tests.sh
```

## FPGA build

Gowin V1.9.12.03 completes synthesis, placement/routing, timing analysis, and bitstream generation for
`GW1NR-LV9QN88PC6/I5` using the 27 MHz constraint in `src/fpga_project.sdc`.

Post-route summary:

| Metric | Result |
|---|---:|
| Constraint | 27.000 MHz |
| Actual Fmax | 33.825 MHz |
| Logic levels | 12 |
| Setup violated endpoints | 0 |
| Hold violated endpoints | 0 |
| Setup TNS | 0.000 ns |
| Hold TNS | 0.000 ns |
| Logic | 2949 / 8640 (35%) |
| Registers | 1463 / 6693 (22%) |
| BSRAM | 5 / 26 (20%) |

The generated SRAM bitstream is `build/gowin/impl/pnr/fpga_project.fs`.

## Hardware

Gowin Programmer detects the Tang Nano 9K as `GW1NR-9C` with ID `0x1100481B`. SRAM programming reaches
100% using the FT2CH JTAG channel. The FT2232 UART interface 1 enumerates as `/dev/ttyUSB1`.

### UART TX

A 115200 baud, 8N1 raw capture of the transmit-only firmware contains an initial `0xff` sample followed by
repeated `0x48` bytes, confirming the UART TX path from CPU MMIO through FPGA pin 17 to the onboard debugger.

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

### Bring-up procedure

The device can be left in a corrupted configuration state, so **always reprogram immediately before
measuring**. During bring-up the board emitted a repeated `0x56` at roughly 2.6 Hz with the RX pin idle,
which looked exactly like an RTL fault; reprogramming a byte-identical bitstream made it disappear. The two
`.fs` files differed only in their timestamp comment.

`ftdi_sio` binds FTDI interface 0, the JTAG channel, as `/dev/ttyUSB0`. Opening or writing that node drives
the FPGA JTAG pins and can disturb the SRAM configuration. Never touch `/dev/ttyUSB0`; the UART is always
interface 1.

`programmer_cli` unloads `ftdi_sio`, so restore the serial port after every programming run:

```bash
sudo modprobe ftdi_sio
ls -l /dev/ttyUSB1
```

The listing must start with `c`. If `/dev/ttyUSB1` is missing, any command containing `>` or `exec 3<>` on
that path creates a regular file that shadows the device node and silently invalidates every later
measurement.

Two throwaway bitstreams isolate a suspected RX fault without involving the CPU. A pure wire,
`assign uart_tx_out = uart_rx_in;`, proves the pin assignment and the host link. A second top module wiring
`uart_rx` straight into `uart_tx` proves the serial RTL. Both target pins 17 and 18 and neither belongs in
the repository.
