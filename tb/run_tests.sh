#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$test_tmp_dir"' EXIT
cd "$repo_dir"

command -v iverilog >/dev/null || {
  echo "iverilog is required" >&2
  exit 1
}
command -v vvp >/dev/null || {
  echo "vvp is required" >&2
  exit 1
}

run_test() {
  local top=$1
  shift
  iverilog -g2012 -s "$top" -o "$test_tmp_dir/$top.vvp" "$@"
  vvp "$test_tmp_dir/$top.vvp"
}

run_test alu_tb src/alu.v tb/alu_tb.sv
run_test control_unit_tb src/control_unit.v tb/control_unit_tb.sv
run_test imm_gen_tb src/imm_gen.v tb/imm_gen_tb.sv
run_test forwarding_unit_tb \
  src/forwarding_unit.v tb/forwarding_unit_tb.sv
run_test hazard_detection_unit_tb \
  src/hazard_detection_unit.v tb/hazard_detection_unit_tb.sv
run_test pipe_if_id_tb src/pipe_if_id.v tb/pipe_if_id_tb.sv
run_test pipe_id_ex_tb src/pipe_id_ex.v tb/pipe_id_ex_tb.sv
run_test pipe_ex_mem_tb src/pipe_ex_mem.v tb/pipe_ex_mem_tb.sv
run_test pipe_mem_wb_tb src/pipe_mem_wb.v tb/pipe_mem_wb_tb.sv
run_test cpu_top_tb src/*.v tb/cpu_top_tb.sv
