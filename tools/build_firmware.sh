#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sw_dir="$repo_dir/sw"
app=${1:-environment}
case "$app" in
  environment)
    build_dir="$repo_dir/build/firmware"
    main_source="$sw_dir/app/main.c"
    ;;
  demo)
    build_dir="$repo_dir/build/demo"
    main_source="$sw_dir/app/mmio_demo.c"
    ;;
  *)
    echo "Usage: $0 [environment|demo]" >&2
    exit 2
    ;;
esac
tool_prefix=${RISCV_TOOL_PREFIX:-riscv64-unknown-elf}

gcc_bin="$tool_prefix-gcc"
objcopy_bin="$tool_prefix-objcopy"
objdump_bin="$tool_prefix-objdump"
nm_bin="$tool_prefix-nm"

for tool in "$gcc_bin" "$objcopy_bin" "$objdump_bin" "$nm_bin"; do
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
  -ffreestanding \
  -I"$sw_dir/app" \
  -I"$sw_dir/hal" \
  -I"$sw_dir/drivers" \
  -I"$sw_dir/graphics" \
  -I"$sw_dir/common" \
  -Os \
  -Wall -Wextra -Werror \
  -fstack-usage \
  -ffunction-sections \
  -fdata-sections \
  -msmall-data-limit=0 \
  -T "$repo_dir/sw/startup/linker.ld" \
  -Wl,--gc-sections \
  -Wl,-Map=firmware.map \
  "$sw_dir/startup/startup.s" \
  "$main_source" \
  "$sw_dir/common/sys_delay.c" \
  "$sw_dir/hal/gpio_led.c" \
  "$sw_dir/hal/uart_io.c" \
  "$sw_dir/hal/i2c_bus.c" \
  "$sw_dir/drivers/ds3231_rtc.c" \
  "$sw_dir/hal/dht11_sensor.c" \
  "$sw_dir/drivers/mq5_sensor.c" \
  "$sw_dir/hal/spi_bus.c" \
  "$sw_dir/graphics/font_8x8.c" \
  "$sw_dir/graphics/ui_assets.c" \
  "$sw_dir/graphics/ui_graphics.c" \
  "$sw_dir/drivers/st7735_panel.c" \
  "$sw_dir/app/ui_clock.c" \
  -o firmware.elf

"$objcopy_bin" -O binary firmware.elf firmware.bin
"$objdump_bin" -d firmware.elf >firmware.asm
python3 "$repo_dir/tools/make_hex.py" firmware.bin firmware.hex
"$nm_bin" -n firmware.elf > firmware.symbols
python3 "$repo_dir/tools/report_memory.py" "$build_dir" | tee memory_usage.txt
if [[ "$app" == environment ]]; then
  mkdir -p "$repo_dir/rom"
  cp firmware.hex "$repo_dir/rom/firmware.hex"
fi
