# Verification logs

This directory holds **decisive logs only** — evidence backing a conclusion that
is cited somewhere in `docs/`. Day-to-day runs do not belong here; run the
commands from the [README](../README.md) and read the output on the terminal.

## Naming

`<index>-<subject>.log`, numbered in the order of the verification chain:
simulation → FPGA build → cable check → programming → on-board measurement.

A log that reproduces a fault keeps the next index and uses a `fault` prefix.
These are kept after the fault is fixed, because they are the "before" half of
the evidence in [../docs/fix_log.md](../docs/fix_log.md).

## Current contents

| File | Produced by | Conclusion it supports |
|---|---|---|
| `01-simulation.log` | `bash tools/run_tests.sh` | 29 / 29 testbenches pass on Icarus Verilog |
| `02-fpga-build.log` | `bash tools/build_fpga.sh` | Gowin completes timing analysis and bitstream generation with no latch warnings |
| `03-jtag-scan.log` | `programmer_cli --scan` | The FT2CH cable detects GW1NR-9C `0x1100481B` |
| `04-program-board.log` | `bash tools/program_fpga.sh` | SRAM programming reaches 100% and reports `Finished.` |
| `05-board-uart.log` | `picocom` on `/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0` | The banner reads `BOOT 5A5A5A5A 00000000`, confirming `.data` was copied and `.bss` cleared; the scan reports `I2C 27` and the 20x4 LCD shows `HELLO FPGA`. Captured mid-run, then across two presses of S2 |
| `06-fault-i2c-nack.log` | as above | Before the ACK sampling phase was fixed, every address returned NACK |
| `07-fault-rodata-null.log` | as above | Before the ROM data window existed, `.rodata` read back as zero: both address bytes arrived as `0x00` |
| `08-fault-hex-branch.log` | as above | Before the register file bypass, the hex formatter's branch was mis-executed and `0x27` printed as `2>` |
| `09-source-layout-refactor.log` | `bash tools/run_tests.sh` | The renamed CPU, peripheral and library tree preserves all 29 testbench contracts |
| `10-source-layout-fpga-build.log` | `bash tools/build_fpga.sh` | The refactored source tree completes P&R, timing analysis and bitstream generation at the existing timing/resource figures |
| `11-source-layout-program-board.log` | `bash tools/program_fpga.sh` | The refactored bitstream reaches 100% SRAM programming and reports `Finished.` |
| `12-uart-rx-fifo-simulation.log` | `bash tools/run_tests.sh` | Interrupted before UART RX because its new testbench reused a loop variable; retained as the pre-fix run record |
| `13-uart-rx-fifo-simulation.log` | `bash tools/run_tests.sh` | 29 / 29 testbenches pass, including UART FIFO order, full, overrun, pop and W1C coverage |
| `14-uart-rx-fifo-full-simulation.log` | `bash tools/run_tests.sh` | 30 / 30 testbenches pass, including CPU-level FIFO pop coverage |
| `15-uart-rx-fifo-fpga-build.log` | `bash tools/build_fpga.sh` | FIFO tree completes P&R, timing analysis and bitstream generation: Fmax 30.210 MHz, 0 setup/hold violations, 3375 logic cells, 1599 registers and 6 BSRAM |

`05-board-uart.log` previously read `I2C 21` and was cited as proof the backpack
answers at `0x21`. That reading was corrupted by the same register file defect;
the address has always been `0x27`. See finding 10 in
[../docs/fix_log.md](../docs/fix_log.md).

`04-program-board.log` has the `programmer_cli` progress-bar animation stripped;
the result lines are verbatim.
