GOWIN_ROOT ?=
FLASH_FREQ ?= 1000000

.PHONY: help clean test firmware fpga program flash

help:
	@printf '%s\n' \
	  'make clean     Remove the build directory.' \
	  'make test      Run the core RTL testbenches.' \
	  'make firmware  Build the firmware and update rom/firmware.hex.' \
	  'make fpga      Build firmware and generate the FPGA bitstream.' \
	  'make program   Build the bitstream and program FPGA SRAM.' \
	  'make flash     Build the bitstream and program persistent Flash.' \
	  'Set GOWIN_ROOT=/path/to/Gowin before FPGA build or programming.'

clean:
	rm -rf -- build

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
