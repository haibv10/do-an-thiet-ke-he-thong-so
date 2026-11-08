GOWIN_ROOT ?=
FLASH_FREQ ?= 1000000
APP ?= environment

.PHONY: help clean format format-check test test-ui test-firmware firmware demo fpga program flash

help:
	@printf '%s\n' \
	  'make clean         Remove the entire build directory.' \
	  'make format        Format RTL, C/header and shell sources.' \
	  'make format-check  Check formatting without modifying files.' \
	  'make test      Run 39 RTL checks (37 testbenches).' \
	  'make firmware  Build the environmental firmware and memory report.' \
	  'make demo      Build the minimal MMIO demo under build/demo/.' \
	  'make test-firmware  Build both apps; test UI, HAL timeouts and demo execution.' \
	  'make test-ui   Check partial TFT updates and render UI snapshots.' \
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
	bash tools/build_firmware.sh "$(APP)"

demo:
	bash tools/build_firmware.sh demo

test-ui:
	bash tools/run_ui_tests.sh

test-firmware:
	bash tools/build_firmware.sh environment
	bash tools/build_firmware.sh demo
	bash tools/run_firmware_tests.sh

fpga: firmware
	GOWIN_ROOT="$(GOWIN_ROOT)" APP="$(APP)" bash tools/build_fpga.sh

program: fpga
	sudo env GOWIN_ROOT="$(GOWIN_ROOT)" bash tools/program_fpga.sh

flash: fpga
	sudo env OPENFPGALOADER_FREQ="$(FLASH_FREQ)" bash tools/program_flash.sh
