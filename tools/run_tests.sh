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

run_test core_alu_tb source/cpu/core_alu.v tb/cpu/core_alu_tb.sv
run_test core_control_tb source/cpu/core_control.v tb/cpu/core_control_tb.sv
run_test core_immediate_tb source/cpu/core_immediate.v tb/cpu/core_immediate_tb.sv
run_test core_regfile_tb source/cpu/core_regfile.v tb/cpu/core_regfile_tb.sv
run_test core_pc_tb source/cpu/core_pc.v tb/cpu/core_pc_tb.sv

run_test reset_sync_tb source/common/reset_sync.v tb/common/reset_sync_tb.sv
run_test clock_enable_tb source/common/clock_enable.v tb/common/clock_enable_tb.sv
run_test pipe_forwarding_tb source/cpu/pipe_forwarding.v tb/cpu/pipe_forwarding_tb.sv
run_test pipe_hazard_tb source/cpu/pipe_hazard.v tb/cpu/pipe_hazard_tb.sv
run_test pipe_if_id_tb source/cpu/pipe_if_id.v tb/cpu/pipe_if_id_tb.sv
run_test pipe_id_ex_tb source/cpu/pipe_id_ex.v tb/cpu/pipe_id_ex_tb.sv
run_test pipe_ex_mem_tb source/cpu/pipe_ex_mem.v tb/cpu/pipe_ex_mem_tb.sv
run_test pipe_mem_wb_tb source/cpu/pipe_mem_wb.v tb/cpu/pipe_mem_wb_tb.sv

run_test cpu_address_decoder_tb source/bus/cpu_address_decoder.v tb/bus/cpu_address_decoder_tb.sv
run_test mem_data_ram_tb source/memory/mem_data_ram.v tb/memory/mem_data_ram_tb.sv
run_test mem_instruction_rom_tb source/memory/mem_instruction_rom.v tb/memory/mem_instruction_rom_tb.sv
run_test gpio_mmio_tb source/peripheral/gpio/gpio_mmio.v tb/peripheral/gpio/gpio_mmio_tb.sv
run_test uart_tx_tb source/peripheral/uart/uart_tx.v tb/peripheral/uart/uart_tx_tb.sv
run_test uart_rx_tb source/peripheral/uart/uart_rx.v tb/peripheral/uart/uart_rx_tb.sv
run_test uart_mmio_tb source/peripheral/uart/uart_tx.v source/peripheral/uart/uart_rx.v source/peripheral/uart/uart_mmio.v tb/peripheral/uart/uart_mmio_tb.sv
run_test i2c_master_tb source/common/clock_enable.v source/peripheral/i2c/i2c_master.v \
  tb/support/i2c_register_slave_model.sv tb/peripheral/i2c/i2c_master_tb.sv
run_test i2c_mmio_tb \
  source/common/clock_enable.v source/peripheral/i2c/i2c_master.v tb/support/i2c_register_slave_model.sv \
  source/peripheral/i2c/i2c_mmio.v tb/peripheral/i2c/i2c_mmio_tb.sv
run_test spi_master_tb source/peripheral/spi/spi_master.v tb/peripheral/spi/spi_master_tb.sv
run_test spi_mmio_tb source/peripheral/spi/spi_master.v source/peripheral/spi/spi_mmio.v tb/peripheral/spi/spi_mmio_tb.sv

soc_sources=(source/*.v source/cpu/*.v source/bus/*.v source/memory/*.v source/common/*.v source/peripheral/*/*.v)
run_test soc_top_tb "${soc_sources[@]}" tb/integration/soc_top_tb.sv
run_test cpu_hazard_tb "${soc_sources[@]}" tb/integration/cpu_hazard_tb.sv
run_test cpu_auipc_tb "${soc_sources[@]}" tb/integration/cpu_auipc_tb.sv
run_test cpu_uart_hex_tb "${soc_sources[@]}" tb/integration/cpu_uart_hex_tb.sv
run_test cpu_uart_fifo_tb "${soc_sources[@]}" tb/integration/cpu_uart_fifo_tb.sv
run_test cpu_i2c_tb "${soc_sources[@]}" tb/support/i2c_register_slave_model.sv tb/integration/cpu_i2c_tb.sv
run_test cpu_spi_tb "${soc_sources[@]}" tb/integration/cpu_spi_tb.sv
run_test cpu_fence_tb "${soc_sources[@]}" tb/integration/cpu_fence_tb.sv
run_test cpu_firmware_boot_tb "${soc_sources[@]}" tb/integration/cpu_firmware_boot_tb.sv
