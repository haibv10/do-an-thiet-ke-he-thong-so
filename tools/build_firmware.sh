#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sw_dir="$repo_dir/sw"
build_dir="$repo_dir/build/firmware"
tool_prefix=${RISCV_TOOL_PREFIX:-riscv64-unknown-elf}

gcc_bin="$tool_prefix-gcc"
objcopy_bin="$tool_prefix-objcopy"
objdump_bin="$tool_prefix-objdump"

for tool in "$gcc_bin" "$objcopy_bin" "$objdump_bin"; do
  command -v "$tool" >/dev/null || {
    echo "$tool is required" >&2
    exit 1
  }
done

mkdir -p "$build_dir"
cd "$build_dir"

"$gcc_bin" \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -O1 \
  -msmall-data-limit=0 \
  -T "$repo_dir/tools/linker_script.ld" \
  -Wl,-Map=firmware.map \
  "$sw_dir/startup.s" \
  "$sw_dir/main.c" \
  "$sw_dir/sys_delay.c" \
  "$sw_dir/gpio_led.c" \
  "$sw_dir/uart_io.c" \
  "$sw_dir/i2c_bus.c" \
  "$sw_dir/ds3231_rtc.c" \
  "$sw_dir/spi_bus.c" \
  "$sw_dir/font_8x8.c" \
  "$sw_dir/st7735_panel.c" \
  "$sw_dir/ui_clock.c" \
  -o firmware.elf

"$objcopy_bin" -O binary firmware.elf firmware.bin
"$objdump_bin" -d firmware.elf > firmware.asm
python3 "$repo_dir/tools/make_hex.py" firmware.bin firmware.hex
mkdir -p "$repo_dir/rom"
cp firmware.hex "$repo_dir/rom/firmware.hex"
