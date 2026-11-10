#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_build_dir="$repo_dir/build/sim"
mkdir -p "$test_build_dir"
cd "$repo_dir"

for tool in iverilog vvp; do
  command -v "$tool" >/dev/null || {
    echo "$tool is required" >&2
    exit 1
  }
done

run_test() {
  local top=$1
  shift
  iverilog -g2012 -s "$top" -o "$test_build_dir/$top.vvp" "$@"
  vvp "$test_build_dir/$top.vvp"
}

soc_sources=(source/*.v source/cpu/*.v source/bus/*.v source/memory/*.v source/common/*.v source/peripheral/*/*.v)

run_test cpu_top_tb source/cpu/*.v tb/cpu/cpu_top_tb.sv
run_test cpu_isa_tb "${soc_sources[@]}" tb/integration/cpu_isa_tb.sv
run_test soc_top_tb "${soc_sources[@]}" tb/integration/soc_top_tb.sv
run_test cpu_firmware_boot_tb "${soc_sources[@]}" tb/integration/cpu_firmware_boot_tb.sv

run_test uart_mmio_tb source/peripheral/uart/*.v tb/peripheral/uart/uart_mmio_tb.sv
run_test i2c_master_tb source/common/clock_enable.v source/peripheral/i2c/i2c_master.v \
  tb/support/i2c_register_slave_model.sv tb/peripheral/i2c/i2c_master_tb.sv
run_test spi_master_tb source/peripheral/spi/spi_master.v tb/peripheral/spi/spi_master_tb.sv
run_test dht11_mmio_tb source/peripheral/dht11/dht11_mmio.v tb/support/dht11_sensor_model.sv \
  tb/peripheral/dht11/dht11_mmio_tb.sv
