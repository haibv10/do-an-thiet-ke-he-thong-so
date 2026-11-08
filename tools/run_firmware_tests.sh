#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$repo_dir/build/tests"
python3 "$repo_dir/tb/firmware/test_memory_report.py"
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror -DMMIO_POLL_LIMIT=8 \
  -I"$repo_dir/sw/hal" "$repo_dir/tb/firmware/hal_timeout_test.c" \
  "$repo_dir/sw/hal/i2c_bus.c" "$repo_dir/sw/hal/spi_bus.c" \
  "$repo_dir/sw/hal/uart_io.c" -o "$repo_dir/build/tests/hal_timeout_test"
timeout 5 "$repo_dir/build/tests/hal_timeout_test"

cd "$repo_dir"
soc_sources=(source/*.v source/cpu/*.v source/bus/*.v source/memory/*.v source/common/*.v source/peripheral/*/*.v)
iverilog -g2012 -s cpu_mmio_demo_tb -o build/tests/cpu_mmio_demo_tb.vvp \
  "${soc_sources[@]}" tb/support/i2c_register_slave_model.sv tb/integration/cpu_mmio_demo_tb.sv
vvp build/tests/cpu_mmio_demo_tb.vvp
