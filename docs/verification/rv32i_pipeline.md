# RV32I pipeline verification

## Simulation

Icarus Verilog 11.0 passes ten self-checking tests. Coverage includes ALU and decode operations, immediate
generation, forwarding priority, load-use hazard detection, pipeline register reset/stall/flush behavior,
branch and JAL flushing, subword memory accesses, GPIO MMIO, and an UART TX frame containing `0x48`.

Command:

```bash
bash tb/run_tests.sh
```

## FPGA build

Gowin V1.9.12.03 completes synthesis, placement/routing, timing analysis, and bitstream generation for
`GW1NR-LV9QN88PC6/I5` using the 27 MHz constraint in `src/fpga_project.sdc`.

Post-route summary:

| Metric | Result |
|---|---:|
| Constraint | 27.000 MHz |
| Actual Fmax | 31.086 MHz |
| Setup violated endpoints | 0 |
| Hold violated endpoints | 0 |
| Setup TNS | 0.000 ns |
| Hold TNS | 0.000 ns |
| Logic | 2911 / 8640 (34%) |
| Registers | 1423 / 6693 (22%) |
| BSRAM | 5 / 26 (20%) |

The generated SRAM bitstream is `impl/pnr/fpga_project.fs`.

## Hardware

Gowin Programmer detects the Tang Nano 9K as `GW1NR-9C` with ID `0x1100481B`. SRAM programming reaches
100% using the FT2CH JTAG channel. The firmware runs after programming and toggles the onboard LED.

The FT2232 UART interface 1 enumerates as `/dev/ttyUSB1`. A 115200 baud, 8N1 raw capture contains an initial
`0xff` sample followed by repeated `0x48` bytes, confirming the firmware UART TX path from CPU MMIO through
FPGA pin 17 to the onboard debugger.
