// Module tiện ích sinh waveform. Không thuộc thiết kế và không được instantiate.
// Biên dịch kèm bất kỳ testbench nào bằng cách thêm `-s dump_vcd` và file này.
// Đường dẫn file VCD lấy từ plusarg +vcd=<path>, mặc định build/sim/wave.vcd
module dump_vcd;
  string vcd_path;

  initial begin
    if (!$value$plusargs("vcd=%s", vcd_path))
      vcd_path = "build/sim/wave.vcd";
    $dumpfile(vcd_path);
    $dumpvars(0);
  end
endmodule
