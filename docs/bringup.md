# Board bring-up

Pitfalls hit while getting this design onto real hardware. Routine build and
programming commands live in the [README](../README.md).

## Always reprogram immediately before measuring

The FPGA can be left in a corrupted configuration state. During bring-up the
board emitted a repeated `0x56` at roughly 2.6 Hz **with the RX pin completely
idle** — a symptom that looked exactly like an RTL fault. Reprogramming a
byte-identical bitstream made it disappear; the two `.fs` files differed only in
their timestamp comment.

The rule that came out of it: **never diagnose an RTL fault on a board that has
not just been reprogrammed.**

## Identify the right serial port

The board carries an FT2232 with two interfaces:

- **Interface 0** — the JTAG channel used for programming
- **Interface 1** — the onboard UART

`ftdi_sio` binds both as `/dev/ttyUSB*`. Opening or writing to the interface 0
node drives the FPGA JTAG pins and can disturb the SRAM configuration.

This design uses an **external USB-UART module** wired to pins 34 (TX) and 33
(RX), so the node to open belongs to that module, not to the FT2232. The
`/dev/ttyUSB*` numbering depends on plug order, so check before opening:

```bash
ls -l /dev/serial/by-id/
```

Match the entries against the external module and the board, then open only the
external module's node.

## Restore the UART after programming

Gowin Programmer unloads `ftdi_sio` when it claims the FT2232 for JTAG. Reload
the driver afterwards to bring the device node back without power-cycling the
board:

```bash
sudo modprobe ftdi_sio
ls -l /dev/ttyUSB*
```

The listing must start with `c` for a character device. If the node is missing,
any command containing `>` or `exec 3<>` on that path creates a regular file
that shadows the device node and silently invalidates every later measurement.

## SRAM programming is volatile

`tools/program_fpga.sh` writes to SRAM (`--run 2`). The bitstream is lost when
the board loses power. Persisting across power cycles requires flash
programming, which this project does not currently use.

## Isolating a UART fault without the CPU

When the serial path is in doubt, two throwaway bitstreams separate the fault
from the CPU:

1. A pure wire, `assign uart_tx_out = uart_rx_in;`, proves the pin assignment
   and the host link.
2. A top module wiring `uart_rx` straight into `uart_tx` proves the serial RTL.

Both are diagnostic scaffolding — build them when needed, then discard. Neither
belongs in the repository.

## I2C logic levels

The I2C pins sit in bank 2, which runs at 3.3 V (`LVCMOS33`). A slave may need
its own 5 V supply, but SDA and SCL **must not** be pulled up to 5 V —
level-shift them or use 3.3 V pull-ups.

No I2C device is wired at present. The HD44780 panel has been removed and the
DS3231 that replaces it is a 3.3 V part, so the same rule holds when it is
fitted: pull SDA and SCL to 3.3 V, never to 5 V.

An earlier capture reported `0x21` and was written up as the real address. It
was not: the reading itself was corrupted by the register file defect recorded
as finding 1 in [fix_log.md](fix_log.md). Read an address off this board only
from a build that carries that fix.
