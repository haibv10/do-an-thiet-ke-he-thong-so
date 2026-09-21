`timescale 1ns/1ps

// Read-after-write dependencies at every distance the pipeline has to cover.
// Distance 1 and 2 are handled by the forwarding unit, distance 3 by the
// write-first bypass in the register file, distance 4 by a plain register read.
module cpu_hazard_tb;
  localparam logic [31:0] NOP = 32'h0000_0013;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire  led_out;
  wire  uart_tx_out;
  integer index;
  integer stall_count = 0;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out),
    .i2c_sda(i2c_sda), .i2c_scl(i2c_scl)
  );

  always @(posedge clk)
    if (rst_n && dut.stall) stall_count <= stall_count + 1;

  function automatic logic [31:0] encode_i(
    input logic [11:0] immediate,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_i = {immediate, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] encode_r(
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [4:0] rd
  );
    encode_r = {7'd0, rs2, rs1, 3'b000, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] addi(
    input logic [4:0] rd,
    input logic [4:0] rs1,
    input logic [11:0] immediate
  );
    addi = encode_i(immediate, rs1, 3'b000, rd, 7'b0010011);
  endfunction

  task automatic expect_reg(
    input integer number,
    input logic [31:0] value,
    input string label
  );
    if (dut.rf.x[number] !== value)
      $fatal(1, "%s: x%0d = %0d, expected %0d",
             label, number, dut.rf.x[number], value);
  endtask

  initial begin
    #1;
    for (index = 0; index < 1024; index = index + 1)
      dut.rom.rom[index] = NOP;

    dut.rom.rom[0]  = {20'h20000, 5'd20, 7'b0110111}; // lui x20, 0x20000
    dut.rom.rom[1]  = addi(5'd1, 5'd0, 12'd4);
    dut.rom.rom[2]  = addi(5'd5, 5'd1, 12'd1);        // distance 1
    dut.rom.rom[3]  = addi(5'd2, 5'd0, 12'd10);
    dut.rom.rom[5]  = addi(5'd6, 5'd2, 12'd1);        // distance 2
    dut.rom.rom[6]  = addi(5'd3, 5'd0, 12'd20);
    dut.rom.rom[9]  = addi(5'd7, 5'd3, 12'd1);        // distance 3
    dut.rom.rom[10] = addi(5'd4, 5'd0, 12'd30);
    dut.rom.rom[14] = addi(5'd8, 5'd4, 12'd1);        // distance 4
    dut.rom.rom[15] = addi(5'd9, 5'd0, 12'd100);
    dut.rom.rom[18] = encode_r(5'd9, 5'd9, 5'd10);    // distance 3, both operands
    dut.rom.rom[19] = addi(5'd11, 5'd0, 12'd77);
    dut.rom.rom[20] = {7'd0, 5'd11, 5'd20, 3'b010, 5'd0, 7'b0100011}; // sw x11, 0(x20)
    dut.rom.rom[21] = encode_i(12'd0, 5'd20, 3'b010, 5'd12, 7'b0000011); // lw x12, 0(x20)
    dut.rom.rom[24] = addi(5'd13, 5'd12, 12'd0);      // distance 3, producer is a load
    dut.rom.rom[25] = encode_i(12'd0, 5'd20, 3'b010, 5'd14, 7'b0000011); // lw x14, 0(x20)
    dut.rom.rom[26] = addi(5'd15, 5'd14, 12'd1);      // distance 1 on a load, must stall
    dut.rom.rom[27] = encode_i(12'd0, 5'd20, 3'b010, 5'd16, 7'b0000011); // lw x16, 0(x20)
    dut.rom.rom[28] = {20'h00080, 5'd17, 7'b0110111}; // lui x17; bits 19:15 = x16
    dut.rom.rom[29] = encode_i(12'd0, 5'd20, 3'b010, 5'd18, 7'b0000011); // lw x18, 0(x20)
    dut.rom.rom[30] = {20'h00090, 5'd19, 7'b0010111}; // auipc x19; bits 19:15 = x18
    dut.rom.rom[31] = 32'h0000_006f;                  // jal x0, 0

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    repeat (70) @(posedge clk);

    expect_reg(5,  32'd5,   "distance 1, forwarded from EX/MEM");
    expect_reg(6,  32'd11,  "distance 2, forwarded from MEM/WB");
    expect_reg(7,  32'd21,  "distance 3, write-first bypass");
    expect_reg(8,  32'd31,  "distance 4, plain register read");
    expect_reg(10, 32'd200, "distance 3 on both operands");
    expect_reg(13, 32'd77,  "distance 3 where the producer is a load");
    expect_reg(15, 32'd78,  "load-use interlock");
    expect_reg(17, 32'h0008_0000, "LUI after a load");
    expect_reg(19, 32'h0009_0078, "AUIPC after a load");

    if (stall_count !== 1)
      $fatal(1, "expected exactly one load-use stall, counted %0d", stall_count);

    $display("cpu_hazard_tb: PASS");
    $finish;
  end
endmodule
