`timescale 1ns/1ps

module imm_gen_tb;
  logic [31:0] instr;
  logic [31:0] imm_out;

  imm_gen dut (.*);

  task automatic check(input logic [31:0] value, input logic [31:0] expected);
    instr = value;
    #1;
    if (imm_out !== expected)
      $fatal(1, "instr=%h immediate=%h expected=%h", value, imm_out, expected);
  endtask

  initial begin
    check(32'hfff0_0093, 32'hffff_ffff);
    check(32'h0031_2423, 32'd8);
    check(32'hfe20_8ee3, 32'hffff_fffc);
    check(32'h1234_52b7, 32'h1234_5000); // LUI
    check(32'h1234_5297, 32'h1234_5000); // AUIPC
    check(32'h0080_006f, 32'd8);
    check(32'h0041_00e7, 32'd4);
    check(32'h0000_0013, 32'd0);
    $display("imm_gen_tb: PASS");
    $finish;
  end
endmodule
