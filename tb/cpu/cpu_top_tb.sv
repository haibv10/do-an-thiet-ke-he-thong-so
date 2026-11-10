`timescale 1ns / 1ps

// Standalone CPU: forwarding, store/load and load-use stall on a short program.
module cpu_top_tb;
  logic clk = 0, rst_n = 0;
  always #18.5 clk = ~clk;

  wire [31:0] instr_addr, data_addr, data_wdata;
  wire [3:0] data_wstrb;
  wire data_re;
  logic [31:0] instr_data, data_rdata;
  logic [31:0] imem[0:63];
  logic [31:0] dmem[0:15];

  cpu_top dut (.*);

  // Same timing as the SoC memories: read on the falling edge.
  always @(negedge clk) begin
    instr_data <= imem[instr_addr[7:2]];
    data_rdata <= dmem[data_addr[5:2]];
    if (data_wstrb == 4'hf) dmem[data_addr[5:2]] <= data_wdata;
  end

  function automatic [31:0] addi(input [4:0] rd, rs1, input [11:0] imm);
    addi = {imm, rs1, 3'b000, rd, 7'b0010011};
  endfunction

  initial begin
    foreach (imem[i]) imem[i] = 32'h00000013;  // NOP
    imem[0] = {20'h20000, 5'd1, 7'b0110111};  // lui  x1, 0x20000
    imem[1] = addi(2, 0, 5);  // addi x2, x0, 5
    imem[2] = addi(3, 2, 3);  // addi x3, x2, 3     (forwarded x2)
    imem[3] = {7'd0, 5'd3, 5'd2, 3'b000, 5'd4, 7'b0110011};  // add x4, x2, x3
    imem[4] = {7'd0, 5'd4, 5'd1, 3'b010, 5'd0, 7'b0100011};  // sw   x4, 0(x1)
    imem[5] = {12'd0, 5'd1, 3'b010, 5'd5, 7'b0000011};  // lw   x5, 0(x1)
    imem[6] = addi(6, 5, 1);  // addi x6, x5, 1     (load-use)
    imem[7] = 32'h0000006f;  // j .

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1;
    repeat (40) @(posedge clk);

    if (dut.rf.x[3] !== 8) $fatal(1, "x3=%0d, expected 8", dut.rf.x[3]);
    if (dut.rf.x[4] !== 13) $fatal(1, "x4=%0d, expected 13", dut.rf.x[4]);
    if (dmem[0] !== 13) $fatal(1, "memory=%0d, expected 13", dmem[0]);
    if (dut.rf.x[6] !== 14) $fatal(1, "x6=%0d, expected 14", dut.rf.x[6]);
    $display("cpu_top_tb: PASS");
    $finish;
  end
endmodule
