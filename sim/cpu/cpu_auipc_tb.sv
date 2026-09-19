`timescale 1ns/1ps

// AUIPC and the ROM data window. Together they are what lets the firmware form
// PC-relative addresses and read constants the linker placed in ROM, which is
// where .rodata and the load image of .data live.
module cpu_auipc_tb;
  localparam logic [31:0] NOP = 32'h0000_0013;
  localparam logic [31:0] ROM_CONSTANT = 32'hdead_beef;
  localparam integer CONSTANT_WORD = 16;                 // byte address 0x40

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire  led_out;
  wire  uart_tx_out;
  tri1  i2c_sda;
  tri1  i2c_scl;
  integer index;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out), .btn_in(1'b0),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out),
    .i2c_sda(i2c_sda), .i2c_scl(i2c_scl)
  );

  function automatic logic [31:0] encode_i(
    input logic [11:0] immediate,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_i = {immediate, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] auipc(
    input logic [19:0] immediate,
    input logic [4:0] rd
  );
    auipc = {immediate, rd, 7'b0010111};
  endfunction

  task automatic expect_reg(
    input integer number,
    input logic [31:0] value,
    input string label
  );
    if (dut.rf.x[number] !== value)
      $fatal(1, "%s: x%0d = %h, expected %h",
             label, number, dut.rf.x[number], value);
  endtask

  initial begin
    #1;
    for (index = 0; index < 1024; index = index + 1)
      dut.rom.rom[index] = NOP;

    dut.rom.rom[0] = auipc(20'h00000, 5'd1);  // x1 = pc(0x00) + 0
    dut.rom.rom[1] = auipc(20'h00000, 5'd2);  // x2 = pc(0x04) + 0
    dut.rom.rom[2] = auipc(20'h12345, 5'd3);  // x3 = pc(0x08) + 0x12345000
    // lw / lbu straight out of the ROM window at region 0x0
    dut.rom.rom[3] = encode_i(12'h040, 5'd0, 3'b010, 5'd4, 7'b0000011);
    dut.rom.rom[4] = encode_i(12'h040, 5'd0, 3'b100, 5'd5, 7'b0000011);
    dut.rom.rom[5] = encode_i(12'h043, 5'd0, 3'b100, 5'd6, 7'b0000011);
    // a store into ROM must be dropped, not corrupt the image
    dut.rom.rom[6] = {7'h2, 5'd1, 5'd0, 3'b010, 5'h0, 7'b0100011}; // sw x1, 0x40(x0)
    dut.rom.rom[7] = auipc(20'h00000, 5'd7);  // x7 = pc(0x1c)
    // PC-relative load: 0x1c + 0x24 = 0x40, the same constant
    dut.rom.rom[8] = encode_i(12'h024, 5'd7, 3'b010, 5'd8, 7'b0000011);
    dut.rom.rom[9] = encode_i(12'h040, 5'd0, 3'b010, 5'd9, 7'b0000011);
    dut.rom.rom[10] = 32'h0000_006f;          // jal x0, 0

    dut.rom.rom[CONSTANT_WORD] = ROM_CONSTANT;

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    repeat (40) @(posedge clk);

    expect_reg(1, 32'h0000_0000, "AUIPC at pc 0x00");
    expect_reg(2, 32'h0000_0004, "AUIPC at pc 0x04");
    expect_reg(3, 32'h1234_5008, "AUIPC with a non-zero immediate");
    expect_reg(4, ROM_CONSTANT,  "LW from the ROM window");
    expect_reg(5, 32'h0000_00ef, "LBU of the low byte in ROM");
    expect_reg(6, 32'h0000_00de, "LBU of the high byte in ROM");
    expect_reg(7, 32'h0000_001c, "AUIPC at pc 0x1c");
    expect_reg(8, ROM_CONSTANT,  "PC-relative LW through AUIPC");
    expect_reg(9, ROM_CONSTANT,  "ROM still intact after a store into region 0x0");

    if (dut.rom.rom[CONSTANT_WORD] !== ROM_CONSTANT)
      $fatal(1, "a store reached the ROM array: %h", dut.rom.rom[CONSTANT_WORD]);

    $display("cpu_auipc_tb: PASS");
    $finish;
  end
endmodule
