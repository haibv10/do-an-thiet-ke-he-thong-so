`timescale 1ns/1ps

module pipe_mem_wb_tb;
  logic clk = 1'b0;
  logic rst_n;
  logic mem_RegWrite, mem_MemtoReg;
  logic [31:0] mem_read_data, mem_alu_result;
  logic [4:0] mem_rd_idx;
  logic wb_RegWrite, wb_MemtoReg;
  logic [31:0] wb_read_data, wb_alu_result;
  logic [4:0] wb_rd_idx;

  always #5 clk = ~clk;
  pipe_mem_wb dut (.*);

  initial begin
    rst_n = 1'b0;
    mem_RegWrite = 1'b1;
    mem_MemtoReg = 1'b1;
    mem_read_data = 32'h1234_5678;
    mem_alu_result = 32'h8765_4321;
    mem_rd_idx = 5'd9;
    #2;
    if ({wb_RegWrite, wb_MemtoReg, wb_read_data,
         wb_alu_result, wb_rd_idx} !== '0) $fatal(1, "reset");
    @(negedge clk) rst_n = 1'b1;
    @(posedge clk); #1;
    if (!wb_RegWrite || !wb_MemtoReg || wb_read_data !== mem_read_data ||
        wb_alu_result !== mem_alu_result || wb_rd_idx !== mem_rd_idx)
      $fatal(1, "capture");
    $display("pipe_mem_wb_tb: PASS");
    $finish;
  end
endmodule
