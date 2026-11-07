`timescale 1ns/1ps

module dump_vcd;
  string vcd_path;

  initial begin
    if (!$value$plusargs("vcd=%s", vcd_path))
      vcd_path = "build/sim/wave.vcd";

    $dumpfile(vcd_path);
    $dumpvars;
  end
endmodule
