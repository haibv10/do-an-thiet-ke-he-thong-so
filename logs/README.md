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
| `17-uart-rx-fifo-program-board.log` | `bash tools/program_fpga.sh` | FIFO bitstream reaches 100% SRAM programming and reports `Finished.` |
| `18-uart-rx-fifo-board-uart.log` | `picocom` on the external USB-UART | FIFO bitstream boots with the `.data`/`.bss` banner and reports PCF8574 at `0x27`; it does not exercise UART RX |
| `19-uart-rx-fifo-board-test-simulation.log` | `bash tools/run_tests.sh` | 30 / 30 tests pass after adding the first board-test firmware command |
| `20-uart-rx-fifo-board-test-final-simulation.log` | `bash tools/run_tests.sh` | 30 / 30 tests pass after removing an impractically slow firmware simulation fixture |
| `21-uart-rx-fifo-board-test-fpga-build.log` | `bash tools/build_fpga.sh` | First board-test firmware bitstream builds successfully |
| `22-uart-rx-fifo-board-test-program.log` | `bash tools/program_fpga.sh` | First board-test bitstream reaches 100% SRAM programming and `Finished.` |
| `23-uart-rx-fifo-board-protocol.log` | `tools/uart_fifo_board_test.py` | Both case markers appear, followed by `RXFIFO FAIL` |
| `24-uart-rx-fifo-board-test-firmware-simulation.log` | `bash tools/run_tests.sh` | 30 / 30 tests pass after rebuilding firmware, before the W1C correction |
| `25-uart-rx-fifo-board-test-firmware-build.log` | `bash tools/build_fpga.sh` | Rebuilt board-test firmware bitstream builds successfully |
| `26-uart-rx-fifo-board-test-firmware-program.log` | `bash tools/program_fpga.sh` | Rebuilt bitstream reaches 100% SRAM programming and `Finished.` |
| `27-uart-rx-fifo-board-test-firmware-protocol.log` | `tools/uart_fifo_board_test.py` | The rebuilt firmware still reports `RXFIFO FAIL` |
| `28-uart-rx-fifo-w1c-fix-simulation.log` | `bash tools/run_tests.sh` | 30 / 30 tests pass; W1C regression checks that status bit `0x04` does not clear the flag |
| `29-uart-rx-fifo-w1c-fix-build.log` | `bash tools/build_fpga.sh` | Corrected W1C firmware tree completes P&R, timing analysis and bitstream generation |
| `30-uart-rx-fifo-w1c-fix-program.log` | `bash tools/program_fpga.sh` | Corrected bitstream reaches 100% SRAM programming and `Finished.` |
| `31-uart-rx-fifo-w1c-fix-protocol.log` | `tools/uart_fifo_board_test.py` | Board test passes ordered 16-byte reception, 17-byte overrun handling and W1C clear |

`05-board-uart.log` previously read `I2C 21` and was cited as proof the backpack
answers at `0x21`. That reading was corrupted by the same register file defect;
the address has always been `0x27`. See finding 10 in
[../docs/fix_log.md](../docs/fix_log.md).

`04-program-board.log` has the `programmer_cli` progress-bar animation stripped;
the result lines are verbatim.
