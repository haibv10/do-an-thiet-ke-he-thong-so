`timescale 1ns/1ps

module pipe_hazard_tb;
  logic [4:0] if_id_rs1;
  logic [4:0] if_id_rs2;
  logic if_id_UsesRs1;
  logic if_id_UsesRs2;
  logic id_ex_MemRead;
  logic [4:0] id_ex_rd;
  logic stall;

  pipe_hazard dut (.*);

  initial begin
    if_id_rs1 = 5'd2;
    if_id_rs2 = 5'd3;
    if_id_UsesRs1 = 1'b1;
    if_id_UsesRs2 = 1'b1;
    id_ex_MemRead = 1'b0;
    id_ex_rd = 5'd2;
    #1;
    if (stall) $fatal(1, "stall without load");
    id_ex_MemRead = 1'b1;
    #1;
    if (!stall) $fatal(1, "rs1 load-use hazard");
    id_ex_rd = 5'd3;
    #1;
    if (!stall) $fatal(1, "rs2 load-use hazard");
    id_ex_rd = 5'd4;
    #1;
    if (stall) $fatal(1, "unrelated load");
    id_ex_rd = 5'd0;
    if_id_rs1 = 5'd0;
    #1;
    if (stall) $fatal(1, "x0 dependency");
    id_ex_rd = 5'd2;
    if_id_rs1 = 5'd2;
    if_id_rs2 = 5'd2;
    if_id_UsesRs1 = 1'b0;
    if_id_UsesRs2 = 1'b0;
    #1;
    if (stall) $fatal(1, "immediate bits caused a false load-use stall");
    $display("pipe_hazard_tb: PASS");
    $finish;
  end
endmodule
