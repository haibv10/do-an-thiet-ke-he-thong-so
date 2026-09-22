`timescale 1ns/1ps

module pipe_id_ex_tb;
  logic clk = 1'b0;
  logic rst_n;
  logic flush;
  logic id_RegWrite, id_MemtoReg, id_MemWrite, id_MemRead;
  logic id_Branch, id_ALUSrc, id_ALUSrcA;
  logic [1:0] id_Jump;
  logic [3:0] id_alu_ctrl;
  logic [2:0] id_funct3;
  logic [31:0] id_pc, id_rd1, id_rd2, id_imm;
  logic [4:0] id_rs1_idx, id_rs2_idx, id_rd_idx;
  logic ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead;
  logic ex_Branch, ex_ALUSrc, ex_ALUSrcA;
  logic [1:0] ex_Jump;
  logic [3:0] ex_alu_ctrl;
  logic [2:0] ex_funct3;
  logic [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm;
  logic [4:0] ex_rs1_idx, ex_rs2_idx, ex_rd_idx;

  always #5 clk = ~clk;
  pipe_id_ex dut (.*);

  initial begin
    rst_n = 1'b0;
    flush = 1'b0;
    {id_RegWrite, id_MemtoReg, id_MemWrite, id_MemRead,
     id_Branch, id_ALUSrc, id_ALUSrcA} = 7'b1011011;
    id_Jump = 2'b10;
    id_alu_ctrl = 4'ha;
    id_funct3 = 3'h5;
    id_pc = 32'h10;
    id_rd1 = 32'h11;
    id_rd2 = 32'h12;
    id_imm = 32'h13;
    id_rs1_idx = 5'd1;
    id_rs2_idx = 5'd2;
    id_rd_idx = 5'd3;
    #2;
    if ({ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead,
         ex_Branch, ex_ALUSrc, ex_ALUSrcA, ex_Jump} !== '0)
      $fatal(1, "reset controls");
    @(negedge clk) rst_n = 1'b1;
    @(posedge clk); #1;
    if (ex_pc !== id_pc || ex_rd1 !== id_rd1 || ex_rd2 !== id_rd2 ||
        ex_imm !== id_imm || ex_rd_idx !== id_rd_idx ||
        ex_Jump !== id_Jump || ex_ALUSrcA !== id_ALUSrcA) $fatal(1, "capture");
    @(negedge clk) flush = 1'b1;
    @(posedge clk); #1;
    if ({ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead,
         ex_Branch, ex_ALUSrc, ex_ALUSrcA, ex_Jump} !== '0)
      $fatal(1, "flush controls");
    if ({ex_pc, ex_rd1, ex_rd2, ex_imm} !== '0) $fatal(1, "flush data");
    $display("pipe_id_ex_tb: PASS");
    $finish;
  end
endmodule
