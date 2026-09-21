#!/usr/bin/env bash
# Run every self-checking testbench under Icarus Verilog.
# Each testbench is compiled independently into build/sim/ and run immediately.
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

# --- CPU core ---
run_test core_alu_tb       source/cpu/core_alu.v       sim/core/core_alu_tb.sv
run_test core_control_tb   source/cpu/core_control.v   sim/core/core_control_tb.sv
run_test core_immediate_tb source/cpu/core_immediate.v sim/core/core_immediate_tb.sv
run_test core_regfile_tb   source/cpu/core_regfile.v   sim/core/core_regfile_tb.sv
run_test core_pc_tb        source/cpu/core_pc.v        sim/core/core_pc_tb.sv

# --- Common and pipeline ---
run_test reset_sync_tb source/common/reset_sync.v sim/common/reset_sync_tb.sv
run_test clock_enable_tb source/common/clock_enable.v sim/common/clock_enable_tb.sv
run_test pipe_forwarding_tb source/cpu/pipe_forwarding.v sim/core/pipe_forwarding_tb.sv
run_test pipe_hazard_tb source/cpu/pipe_hazard.v sim/core/pipe_hazard_tb.sv
run_test pipe_if_id_tb source/cpu/pipe_if_id.v sim/core/pipe_if_id_tb.sv
run_test pipe_id_ex_tb source/cpu/pipe_id_ex.v sim/core/pipe_id_ex_tb.sv
run_test pipe_ex_mem_tb source/cpu/pipe_ex_mem.v sim/core/pipe_ex_mem_tb.sv
run_test pipe_mem_wb_tb source/cpu/pipe_mem_wb.v sim/core/pipe_mem_wb_tb.sv

# --- Memory, bus, and peripherals ---
run_test cpu_address_decoder_tb source/cpu/cpu_address_decoder.v sim/cpu/cpu_address_decoder_tb.sv
run_test mem_data_ram_tb source/cpu/mem_data_ram.v sim/memory/mem_data_ram_tb.sv
run_test mem_instruction_rom_tb source/cpu/mem_instruction_rom.v sim/memory/mem_instruction_rom_tb.sv
run_test gpio_mmio_tb source/peripheral/gpio_mmio.v sim/peripheral/gpio_mmio_tb.sv
run_test uart_tx_tb libs/uart/uart_tx.v libs/uart/uart_tx_tb.sv
run_test uart_rx_tb libs/uart/uart_rx.v libs/uart/uart_rx_tb.sv
run_test uart_mmio_tb libs/uart/uart_tx.v libs/uart/uart_rx.v source/peripheral/uart_mmio.v sim/peripheral/uart_mmio_tb.sv
run_test i2c_write_frame_tb source/common/clock_enable.v libs/i2c/i2c_write_frame.v libs/i2c/i2c_write_frame_tb.sv
run_test i2c_pcf8574_lcd_write_tb \
  source/common/clock_enable.v libs/i2c/i2c_write_frame.v libs/i2c/i2c_pcf8574_lcd_write.v \
  libs/i2c/i2c_pcf8574_lcd_write_tb.sv
run_test pcf8574_lcd_mmio_tb \
  source/common/clock_enable.v libs/i2c/i2c_write_frame.v libs/i2c/i2c_pcf8574_lcd_write.v \
  source/peripheral/pcf8574_lcd_mmio.v sim/peripheral/pcf8574_lcd_mmio_tb.sv
run_test spi_master_tb libs/spi/spi_master.v libs/spi/spi_master_tb.sv
run_test spi_mmio_tb libs/spi/spi_master.v source/peripheral/spi_mmio.v sim/peripheral/spi_mmio_tb.sv
run_test i2c_lcd_20x4_refresh_tb libs/i2c/i2c_lcd_20x4_refresh.v libs/i2c/i2c_lcd_20x4_refresh_tb.sv

# --- CPU integration ---
cpu_sources=(source/cpu/*.v source/peripheral/*.v source/common/*.v libs/i2c/*.v libs/uart/*.v libs/spi/*.v)
run_test cpu_top_tb "${cpu_sources[@]}" sim/cpu/cpu_top_tb.sv
run_test cpu_hazard_tb "${cpu_sources[@]}" sim/cpu/cpu_hazard_tb.sv
run_test cpu_auipc_tb "${cpu_sources[@]}" sim/cpu/cpu_auipc_tb.sv
run_test cpu_uart_hex_tb "${cpu_sources[@]}" sim/cpu/cpu_uart_hex_tb.sv
run_test cpu_uart_fifo_tb "${cpu_sources[@]}" sim/cpu/cpu_uart_fifo_tb.sv
run_test cpu_spi_tb "${cpu_sources[@]}" sim/cpu/cpu_spi_tb.sv
run_test cpu_fence_tb "${cpu_sources[@]}" sim/cpu/cpu_fence_tb.sv
run_test cpu_firmware_boot_tb "${cpu_sources[@]}" sim/cpu/cpu_firmware_boot_tb.sv
