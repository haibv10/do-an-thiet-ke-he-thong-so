`timescale 1ns/1ps

module regfile_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic [4:0] rs1 = 5'd0;
  logic [4:0] rs2 = 5'd0;
  logic [4:0] rd = 5'd0;
  logic [31:0] wd = 32'd0;
  wire [31:0] rd1;
  wire [31:0] rd2;

  regfile dut (.*);

  always #5 clk = ~clk;

  // Drive a write for one cycle, holding the write ports stable across the edge.
  task automatic write_reg(input logic [4:0] index, input logic [31:0] value);
    begin
      @(negedge clk);
      we = 1'b1;
      rd = index;
      wd = value;
      @(negedge clk);
      we = 1'b0;
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    // Reset clears every slot.
    rs1 = 5'd7;
    #1;
    if (rd1 !== 32'd0) $fatal(1, "x7 after reset = %h", rd1);

    // Plain write then read on a later cycle.
    write_reg(5'd7, 32'hdead_beef);
    rs1 = 5'd7;
    #1;
    if (rd1 !== 32'hdead_beef) $fatal(1, "x7 readback = %h", rd1);

    // x0 is hardwired to zero and never stores a write.
    write_reg(5'd0, 32'hffff_ffff);
    rs1 = 5'd0;
    #1;
    if (rd1 !== 32'd0) $fatal(1, "x0 = %h, must stay zero", rd1);

    // Write-first bypass: while the write is still pending at the clock edge,
    // both read ports must already return the incoming data.
    @(negedge clk);
    we = 1'b1;
    rd = 5'd9;
    wd = 32'h1234_5678;
    rs1 = 5'd9;
    rs2 = 5'd9;
    #1;
    if (rd1 !== 32'h1234_5678 || rd2 !== 32'h1234_5678)
      $fatal(1, "bypass rd1=%h rd2=%h expected 12345678", rd1, rd2);

    // A non-matching index must not pick up the bypass.
    rs2 = 5'd7;
    #1;
    if (rd2 !== 32'hdead_beef) $fatal(1, "x7 during unrelated write = %h", rd2);

    // The bypass must not fire for x0 even when rd is x0.
    @(negedge clk);
    we = 1'b1;
    rd = 5'd0;
    wd = 32'hffff_ffff;
    rs1 = 5'd0;
    #1;
    if (rd1 !== 32'd0) $fatal(1, "x0 bypassed a write = %h", rd1);

    // The bypass must not fire while write enable is low.
    @(negedge clk);
    we = 1'b0;
    rd = 5'd7;
    wd = 32'h0bad_0bad;
    rs1 = 5'd7;
    #1;
    if (rd1 !== 32'hdead_beef) $fatal(1, "bypassed with we low = %h", rd1);

    $display("regfile_tb: PASS");
    $finish;
  end
endmodule
