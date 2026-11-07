`timescale 1ns/1ps

module pipe_forwarding_tb;
  logic [4:0] id_ex_rs1;
  logic [4:0] id_ex_rs2;
  logic ex_mem_RegWrite;
  logic [4:0] ex_mem_rd;
  logic mem_wb_RegWrite;
  logic [4:0] mem_wb_rd;
  logic [1:0] forward_a;
  logic [1:0] forward_b;

  pipe_forwarding dut (.*);

  initial begin
    id_ex_rs1 = 5'd3;
    id_ex_rs2 = 5'd4;
    ex_mem_RegWrite = 1'b0;
    ex_mem_rd = '0;
    mem_wb_RegWrite = 1'b0;
    mem_wb_rd = '0;
    #1;
    if ({forward_a, forward_b} != 4'b0000) $fatal(1, "no forwarding");

    ex_mem_RegWrite = 1'b1;
    ex_mem_rd = 5'd3;
    mem_wb_RegWrite = 1'b1;
    mem_wb_rd = 5'd4;
    #1;
    if (forward_a != 2'b10 || forward_b != 2'b01) $fatal(1, "independent paths");

    mem_wb_rd = 5'd3;
    #1;
    if (forward_a != 2'b10) $fatal(1, "MEM priority");

    id_ex_rs1 = 5'd0;
    ex_mem_rd = 5'd0;
    mem_wb_rd = 5'd0;
    #1;
    if (forward_a != 2'b00) $fatal(1, "x0 forwarding");
    $display("pipe_forwarding_tb: PASS");
    $finish;
  end
endmodule
