# Verification logs

This directory holds **decisive logs only** — evidence backing a conclusion that
is cited somewhere in `docs/`. Day-to-day runs do not belong here; run the
commands from the [README](../README.md) and read the output on the terminal.

## Naming

`<index>-<subject>.log`, numbered in the order of the verification chain:
simulation → FPGA build → cable check → programming → on-board measurement.

A log that reproduces a fault which has since been fixed keeps the next index and
uses a `fault` prefix, because those are the evidence behind the "known
limitations" sections of the documentation.

## Current contents

| File | Produced by | Conclusion it supports |
|---|---|---|
| `01-simulation.log` | `bash tools/run_tests.sh` | 18 / 18 testbenches pass on Icarus Verilog |
| `02-fpga-build.log` | `bash tools/build_fpga.sh` | Gowin completes timing analysis and bitstream generation with no latch warnings |
| `03-jtag-scan.log` | `programmer_cli --scan` | The FT2CH cable detects GW1NR-9C `0x1100481B` |
| `04-program-board.log` | `bash tools/program_fpga.sh` | SRAM programming reaches 100% and reports `Finished.` |
| `05-board-uart.log` | `picocom` on `/dev/ttyUSB0` | Firmware prints `I2C 21`; the 20x4 LCD shows `HELLO FPGA` |
| `06-fault-i2c-nack.log` | as above | Before the ACK sampling phase was fixed, every address returned NACK |
| `07-fault-rodata-null.log` | as above | `.rodata` is unreachable over the data bus: both address bytes read back as `0x00` |
| `08-fault-hex-branch.log` | as above | The hex character branch is mis-executed by the pipeline: `0x27` prints as `2>` |

`04-program-board.log` has the `programmer_cli` progress-bar animation stripped;
the result lines are verbatim.
