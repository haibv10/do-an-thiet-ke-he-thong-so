`timescale 1ns/1ps

module core_pc_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic stall = 1'b0;
  logic [31:0] pc_next = 32'd0;
  wire  [31:0] pc;

  core_pc dut (.*);

  always #5 clk = ~clk;

  initial begin

    @(negedge clk);
    #1;
    if (pc !== 32'h0000_0000) $fatal(1, "pc = %h out of reset", pc);

    @(negedge clk) rst_n = 1'b1;

    pc_next = 32'h0000_0004;
    @(posedge clk); #1;
    if (pc !== 32'h0000_0004) $fatal(1, "pc = %h, expected 4", pc);

    pc_next = 32'h0000_0008;
    @(posedge clk); #1;
    if (pc !== 32'h0000_0008) $fatal(1, "pc = %h, expected 8", pc);

    @(negedge clk) stall = 1'b1;
    pc_next = 32'h0000_00cc;
    repeat (3) @(posedge clk);
    #1;
    if (pc !== 32'h0000_0008) $fatal(1, "pc moved to %h while stalled", pc);

    @(negedge clk) stall = 1'b0;
    pc_next = 32'h0000_000c;
    @(posedge clk); #1;
    if (pc !== 32'h0000_000c) $fatal(1, "pc = %h after the stall", pc);

    pc_next = 32'h0000_1000;
    @(posedge clk); #1;
    if (pc !== 32'h0000_1000) $fatal(1, "pc = %h, expected a branch target", pc);

    @(negedge clk) stall = 1'b1;
    #1;
    rst_n = 1'b0;
    #1;
    if (pc !== 32'h0000_0000) $fatal(1, "pc = %h, reset did not take", pc);

    $display("core_pc_tb: PASS");
    $finish;
  end
endmodule
