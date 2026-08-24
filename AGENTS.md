# Repository Guidelines

## Project Structure

- `README.md` describes the RISC-V SoC objective, architecture, peripherals, and scope.
- `docs/images/` contains I2C/LCD schematics, FSM diagrams, waveforms, and hardware demo assets.
- `rules/` contains the repository coding and commit conventions.
- RTL, testbench, and firmware directories are not established yet. When added, keep RTL in `src/`, simulation files in `tb/`, and RISC-V firmware in `sw/`.

## Architecture Overview

The target system is a 32-bit RISC-V RV32I SoC for FPGA with a five-stage pipeline, instruction/data memory,
and Memory-Mapped I/O. GPIO controls LEDs and reads switches/buttons; UART communicates with a laptop;
I2C is reserved for the LCD demo. Keep peripheral interfaces independent from the CPU and connect them
through an address decoder.

## Build, Test, and Development

No repository-wide build script, simulator command, or FPGA tool project is currently defined. Do not invent
passing build results. Before submitting documentation or RTL changes, use:

```bash
rg --files
git diff --check
```

Once an FPGA project and testbenches are added, commit the exact synthesis, simulation, and programming
commands to the repository documentation. Run module-level simulation before full-SoC synthesis.

## Coding Style and Naming

Follow `rules/verilog_coding_style.md`: use SystemVerilog-2017, two-space indentation, lowercase `snake_case`
for files/modules/signals, `logic` for signals, `always_ff` for sequential logic, and `always_comb` for
combinational logic. Use descriptive names such as `uart_rx`, `gpio_led`, and `i2c_lcd_controller`.
Keep clock and reset behavior explicit, and avoid adding compatibility outside the stated FPGA scope.

## Testing Guidelines

There is no test framework or coverage threshold yet. New RTL should include a matching testbench named
`<module_name>_tb.sv` under `tb/`, covering reset, normal transactions, boundary cases, and externally
visible outputs. Record the simulator and relevant waveform or synthesis evidence when available.

## Commits and Pull Requests

Use Conventional Commits as defined in `rules/commit_style.md`, for example `feat(uart): add tx register`
or `docs: clarify i2c lcd scope`. Keep descriptions lowercase, imperative, and without a trailing period.
Pull requests should explain the change, list verification performed, identify FPGA/tool assumptions, and
include waveform or hardware evidence for behavior changes.
