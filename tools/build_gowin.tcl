# Gowin headless flow: synthesis -> place & route -> timing -> bitstream.
# Invoke through tools/build_fpga.sh so the required environment is set up.

set tools_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $tools_dir]

set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

# --- CPU core ---
add_file [file join $repo_dir src cpu_top.v]
add_file [file join $repo_dir src pc_reg.v]
add_file [file join $repo_dir src control_unit.v]
add_file [file join $repo_dir src imm_gen.v]
add_file [file join $repo_dir src alu.v]
add_file [file join $repo_dir src regfile.v]

# --- Pipeline registers ---
add_file [file join $repo_dir src pipe_if_id.v]
add_file [file join $repo_dir src pipe_id_ex.v]
add_file [file join $repo_dir src pipe_ex_mem.v]
add_file [file join $repo_dir src pipe_mem_wb.v]
add_file [file join $repo_dir src forwarding_unit.v]
add_file [file join $repo_dir src hazard_detection_unit.v]

# --- Memory and bus ---
add_file [file join $repo_dir src imem.v]
add_file [file join $repo_dir src dmem.v]
add_file [file join $repo_dir src address_decoder.v]

# --- Peripherals ---
add_file [file join $repo_dir src gpio.v]
add_file [file join $repo_dir src uart_mmio.v]
add_file [file join $repo_dir src uart_tx.v]
add_file [file join $repo_dir src uart_rx.v]
add_file [file join $repo_dir src i2c_mmio.v]
add_file [file join $repo_dir src lcd_write_cmd_data.v]
add_file [file join $repo_dir src i2c_writeframe.v]
add_file [file join $repo_dir src clock_enable_divider.v]

# --- Constraints ---
add_file [file join $repo_dir constr fpga_project.cst]
add_file [file join $repo_dir constr fpga_project.sdc]

set_option -top_module cpu_top
set_option -verilog_std v2001
set_option -output_base_name fpga_project
set_option -print_all_synthesis_warning 1

run all
