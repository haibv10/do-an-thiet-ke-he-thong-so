`timescale 1ns/1ps

module core_control_tb;
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic funct7_5;
  logic Branch;
  logic [1:0] Jump;
  logic MemRead;
  logic MemtoReg;
  logic MemWrite;
  logic ALUSrc;
  logic ALUSrcA;
  logic RegWrite;
  logic UsesRs1;
  logic UsesRs2;
  logic Fence;
  logic [3:0] alu_ctrl;

  core_control dut (.*);

  task automatic decode(
    input logic [6:0] op,
    input logic [2:0] f3,
    input logic f7
  );
    opcode = op;
    funct3 = f3;
    funct7_5 = f7;
    #1;
  endtask

  initial begin
    decode(7'b0110011, 3'b000, 1'b0);
    if (!RegWrite || ALUSrc || !UsesRs1 || !UsesRs2 || alu_ctrl != 4'b0000)
      $fatal(1, "ADD decode");
    decode(7'b0110011, 3'b000, 1'b1);
    if (alu_ctrl != 4'b1000) $fatal(1, "SUB decode");
    decode(7'b0010011, 3'b101, 1'b1);
    if (!RegWrite || !ALUSrc || !UsesRs1 || UsesRs2 || alu_ctrl != 4'b1101)
      $fatal(1, "SRAI decode");
    decode(7'b0110111, 3'b000, 1'b0);
    if (!RegWrite || !ALUSrc || ALUSrcA || UsesRs1 || UsesRs2 || alu_ctrl != 4'b1111)
      $fatal(1, "LUI decode");
    decode(7'b0010111, 3'b000, 1'b0);
    if (!RegWrite || !ALUSrc || !ALUSrcA || UsesRs1 || UsesRs2 || alu_ctrl != 4'b0000)
      $fatal(1, "AUIPC decode");
    decode(7'b0000011, 3'b010, 1'b0);
    if (!MemRead || !MemtoReg || !RegWrite || !ALUSrc || !UsesRs1 || UsesRs2)
      $fatal(1, "load decode");
    decode(7'b0100011, 3'b010, 1'b0);
    if (!MemWrite || !ALUSrc || RegWrite || !UsesRs1 || !UsesRs2)
      $fatal(1, "store decode");
    decode(7'b1100011, 3'b001, 1'b0);
    if (!Branch || !UsesRs1 || !UsesRs2 || alu_ctrl != 4'b1000)
      $fatal(1, "branch decode");
    decode(7'b1101111, 3'b000, 1'b0);
    if (Jump != 2'b01 || !RegWrite || UsesRs1 || UsesRs2) $fatal(1, "JAL decode");
    decode(7'b1100111, 3'b000, 1'b0);
    if (Jump != 2'b10 || !RegWrite || !ALUSrc || !UsesRs1 || UsesRs2)
      $fatal(1, "JALR decode");
    decode(7'b0001111, 3'b000, 1'b0);
    if (!Fence || UsesRs1 || UsesRs2 || RegWrite || MemRead || MemWrite)
      $fatal(1, "FENCE decode");
    decode(7'b1111111, 3'b111, 1'b1);
    if ({Branch, Jump, MemRead, MemtoReg, MemWrite, ALUSrc, ALUSrcA, RegWrite,
         UsesRs1, UsesRs2, Fence} != '0)
      $fatal(1, "illegal opcode defaults");
    $display("core_control_tb: PASS");
    $finish;
  end
endmodule
