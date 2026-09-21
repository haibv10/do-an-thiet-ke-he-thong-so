`timescale 1ns/1ps

module pipe_ex_mem_tb;
  logic clk = 1'b0;
  logic rst_n;
  logic ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead, ex_Branch;
  logic [31:0] ex_branch_target, ex_alu_result, ex_rd2;
  logic ex_zero;
  logic [4:0] ex_rd_idx;
  logic [2:0] ex_funct3;
  logic mem_RegWrite, mem_MemtoReg, mem_MemWrite, mem_MemRead, mem_Branch;
  logic [31:0] mem_branch_target, mem_alu_result, mem_rd2;
  logic mem_zero;
  logic [4:0] mem_rd_idx;
  logic [2:0] mem_funct3;

  always #5 clk = ~clk;
  pipe_ex_mem dut (.*);

  initial begin
    rst_n = 1'b0;
    {ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead, ex_Branch} = 5'b10101;
    ex_branch_target = 32'h100;
    ex_zero = 1'b1;
    ex_alu_result = 32'h200;
    ex_rd2 = 32'h300;
    ex_rd_idx = 5'd7;
    ex_funct3 = 3'h2;
    #2;
    if ({mem_RegWrite, mem_MemtoReg, mem_MemWrite,
         mem_MemRead, mem_Branch} !== '0) $fatal(1, "reset");
    @(negedge clk) rst_n = 1'b1;
    @(posedge clk); #1;
    if ({mem_RegWrite, mem_MemtoReg, mem_MemWrite, mem_MemRead,
         mem_Branch} !== 5'b10101) $fatal(1, "control capture");
    if (mem_branch_target !== ex_branch_target || mem_zero !== ex_zero ||
        mem_alu_result !== ex_alu_result || mem_rd2 !== ex_rd2 ||
        mem_rd_idx !== ex_rd_idx || mem_funct3 !== ex_funct3)
      $fatal(1, "data capture");
    $display("pipe_ex_mem_tb: PASS");
    $finish;
  end
endmodule
