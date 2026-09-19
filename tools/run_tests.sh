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

# --- CPU: combinational and decode blocks ---
run_test alu_tb          src/alu.v          tb/alu_tb.sv
run_test control_unit_tb src/control_unit.v tb/control_unit_tb.sv
run_test imm_gen_tb      src/imm_gen.v      tb/imm_gen_tb.sv
run_test regfile_tb      src/regfile.v      tb/regfile_tb.sv
run_test pc_reg_tb       src/pc_reg.v       tb/pc_reg_tb.sv

run_test reset_sync_tb   src/reset_sync.v   tb/reset_sync_tb.sv

# --- CPU: hazard handling and pipeline registers ---
run_test forwarding_unit_tb        src/forwarding_unit.v        tb/forwarding_unit_tb.sv
run_test hazard_detection_unit_tb  src/hazard_detection_unit.v  tb/hazard_detection_unit_tb.sv
run_test pipe_if_id_tb             src/pipe_if_id.v             tb/pipe_if_id_tb.sv
run_test pipe_id_ex_tb             src/pipe_id_ex.v             tb/pipe_id_ex_tb.sv
run_test pipe_ex_mem_tb            src/pipe_ex_mem.v            tb/pipe_ex_mem_tb.sv
run_test pipe_mem_wb_tb            src/pipe_mem_wb.v            tb/pipe_mem_wb_tb.sv

# --- Memory and bus ---
run_test address_decoder_tb src/address_decoder.v tb/address_decoder_tb.sv
run_test dmem_tb            src/dmem.v            tb/dmem_tb.sv
run_test imem_tb            src/imem.v            tb/imem_tb.sv

# --- Peripherals: GPIO ---
run_test gpio_tb src/gpio.v tb/gpio_tb.sv

# --- Peripherals: UART ---
run_test uart_tx_tb   src/uart_tx.v tb/uart_tx_tb.sv
run_test uart_rx_tb   src/uart_rx.v tb/uart_rx_tb.sv
run_test uart_mmio_tb src/uart_tx.v src/uart_rx.v src/uart_mmio.v tb/uart_mmio_tb.sv

# --- Peripherals: I2C and LCD ---
run_test clock_enable_divider_tb src/clock_enable_divider.v tb/clock_enable_divider_tb.sv
run_test i2c_writeframe_tb \
  src/clock_enable_divider.v src/i2c_writeframe.v tb/i2c_writeframe_tb.sv
run_test lcd_write_cmd_data_tb \
  src/clock_enable_divider.v src/i2c_writeframe.v src/lcd_write_cmd_data.v \
  tb/lcd_write_cmd_data_tb.sv
run_test i2c_mmio_tb \
  src/clock_enable_divider.v src/i2c_writeframe.v \
  src/lcd_write_cmd_data.v src/i2c_mmio.v tb/i2c_mmio_tb.sv
run_test lcd_display_tb src/lcd_display.v tb/lcd_display_tb.sv

# --- Full SoC integration ---
run_test cpu_top_tb      src/*.v tb/cpu_top_tb.sv
run_test cpu_hazard_tb   src/*.v tb/cpu_hazard_tb.sv
run_test cpu_auipc_tb    src/*.v tb/cpu_auipc_tb.sv
run_test uart_hex_cpu_tb src/*.v tb/uart_hex_cpu_tb.sv

# --- End to end: the real firmware image on the real SoC ---
run_test firmware_boot_tb src/*.v tb/firmware_boot_tb.sv
