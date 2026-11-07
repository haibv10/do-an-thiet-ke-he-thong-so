GOWIN_ROOT ?=
FLASH_FREQ ?= 1000000

.PHONY: help clean format format-check test firmware fpga program flash

help:
	@printf '%s\n' \
	  'make clean         Remove the entire build directory.' \
	  'make format        Format RTL, C/header and shell sources.' \
	  'make format-check  Check formatting without modifying files.' \
	  'make test      Run all 33 RTL testbenches.' \
	  'make firmware  Build the RISC-V firmware ROM image.' \
	  'make fpga      Build firmware and generate the FPGA bitstream.' \
	  'make program   Build the bitstream and program FPGA SRAM.' \
	  'make flash     Build the bitstream and program persistent Flash.' \
	  'Set GOWIN_ROOT=/path/to/Gowin before FPGA build or programming.'

clean:
	rm -rf -- build

format:
	bash tools/format_source.sh --write

format-check:
	bash tools/format_source.sh --check

test:
	bash tools/run_tests.sh

firmware:
	bash tools/build_firmware.sh

fpga: firmware
	GOWIN_ROOT="$(GOWIN_ROOT)" bash tools/build_fpga.sh

program: fpga
	sudo env GOWIN_ROOT="$(GOWIN_ROOT)" bash tools/program_fpga.sh

flash: fpga
	sudo env OPENFPGALOADER_FREQ="$(FLASH_FREQ)" bash tools/program_flash.sh
