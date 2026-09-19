`timescale 1ns/1ps

module pipe_if_id_tb;
  logic clk = 1'b0;
  logic rst_n;
  logic stall;
  logic flush;
  logic [31:0] if_pc;
  logic [31:0] if_instr;
  logic [31:0] id_pc;
  logic [31:0] id_instr;

  always #5 clk = ~clk;
  pipe_if_id dut (.*);

  initial begin
    rst_n = 1'b0;
    stall = 1'b0;
    flush = 1'b0;
    if_pc = 32'h100;
    if_instr = 32'h1234_5678;
    #2;
    if (id_pc !== 0 || id_instr !== 32'h0000_0013) $fatal(1, "reset");
    @(negedge clk) rst_n = 1'b1;
    @(posedge clk); #1;
    if (id_pc !== if_pc || id_instr !== if_instr) $fatal(1, "capture");
    @(negedge clk) begin
      stall = 1'b1;
      if_pc = 32'h104;
      if_instr = 32'h8765_4321;
    end
    @(posedge clk); #1;
    if (id_pc !== 32'h100 || id_instr !== 32'h1234_5678) $fatal(1, "stall");
    @(negedge clk) begin stall = 1'b0; flush = 1'b1; end
    @(posedge clk); #1;
    if (id_pc !== 0 || id_instr !== 32'h0000_0013) $fatal(1, "flush");
    $display("pipe_if_id_tb: PASS");
    $finish;
  end
endmodule
