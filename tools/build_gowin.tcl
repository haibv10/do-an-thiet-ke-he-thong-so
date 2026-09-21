# Gowin headless flow: synthesis -> place & route -> timing -> bitstream.
# Invoke through tools/build_fpga.sh so the required environment is set up.

set tools_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $tools_dir]

set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

# --- CPU core ---
add_file [file join $repo_dir source cpu cpu_top.v]
add_file [file join $repo_dir source cpu core_pc.v]
add_file [file join $repo_dir source common reset_sync.v]
add_file [file join $repo_dir source cpu core_control.v]
add_file [file join $repo_dir source cpu core_immediate.v]
add_file [file join $repo_dir source cpu core_alu.v]
add_file [file join $repo_dir source cpu core_regfile.v]

# --- Pipeline registers ---
add_file [file join $repo_dir source cpu pipe_if_id.v]
add_file [file join $repo_dir source cpu pipe_id_ex.v]
add_file [file join $repo_dir source cpu pipe_ex_mem.v]
add_file [file join $repo_dir source cpu pipe_mem_wb.v]
add_file [file join $repo_dir source cpu pipe_forwarding.v]
add_file [file join $repo_dir source cpu pipe_hazard.v]

# --- Memory and bus ---
add_file [file join $repo_dir source cpu mem_instruction_rom.v]
add_file [file join $repo_dir source cpu mem_data_ram.v]
add_file [file join $repo_dir source cpu cpu_address_decoder.v]

# --- Peripherals ---
add_file [file join $repo_dir source peripheral gpio_mmio.v]
add_file [file join $repo_dir source peripheral uart_mmio.v]
add_file [file join $repo_dir libs uart uart_tx.v]
add_file [file join $repo_dir libs uart uart_rx.v]
add_file [file join $repo_dir source peripheral pcf8574_lcd_mmio.v]
add_file [file join $repo_dir libs i2c i2c_pcf8574_lcd_write.v]
add_file [file join $repo_dir libs i2c i2c_write_frame.v]
add_file [file join $repo_dir source peripheral spi_mmio.v]
add_file [file join $repo_dir libs spi spi_master.v]
add_file [file join $repo_dir source common clock_enable.v]

# --- Constraints ---
add_file [file join $repo_dir constr fpga_project.cst]
add_file [file join $repo_dir constr fpga_project.sdc]

set_option -top_module cpu_top
set_option -verilog_std v2001
set_option -output_base_name fpga_project
set_option -print_all_synthesis_warning 1

run all
