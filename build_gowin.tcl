set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

add_file src/address_decoder.v
add_file src/alu.v
add_file src/control_unit.v
add_file src/cpu_top.v
add_file src/dmem.v
add_file src/forwarding_unit.v
add_file src/gpio.v
add_file src/hazard_detection_unit.v
add_file src/imem.v
add_file src/imm_gen.v
add_file src/pc_reg.v
add_file src/pipe_ex_mem.v
add_file src/pipe_id_ex.v
add_file src/pipe_if_id.v
add_file src/pipe_mem_wb.v
add_file src/regfile.v
add_file src/uart_tx.v
add_file src/fpga_project.cst
add_file src/fpga_project.sdc

set_option -top_module cpu_top
set_option -verilog_std v2001
set_option -output_base_name fpga_project
set_option -print_all_synthesis_warning 1

run all
