// Waveform dump helper. Not part of the design and never instantiated.
// Compile it alongside any testbench by adding `-s dump_vcd` and this file.
// The VCD path comes from the +vcd=<path> plusarg, defaulting to build/sim/wave.vcd
module dump_vcd;
  string vcd_path;

  initial begin
    if (!$value$plusargs("vcd=%s", vcd_path))
      vcd_path = "build/sim/wave.vcd";
    $dumpfile(vcd_path);
    $dumpvars(0);
  end
endmodule
