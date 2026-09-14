set tools_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $tools_dir]

set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

add_file [file join $repo_dir src uart_loopback_top.v]
add_file [file join $repo_dir src uart_loopback_reverse.cst]
add_file [file join $repo_dir src fpga_project.sdc]

set_option -top_module uart_loopback_top
set_option -verilog_std v2001
set_option -output_base_name uart_loopback
set_option -print_all_synthesis_warning 1

run all
