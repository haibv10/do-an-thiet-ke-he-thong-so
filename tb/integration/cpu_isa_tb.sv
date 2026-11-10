`timescale 1ns / 1ps

// Runs each RV32I instruction once inside the SoC and checks the result.
module cpu_isa_tb;
  logic clk = 0, rst_n = 0;
  always #18.5 clk = ~clk;

  soc_top dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .uart_rx_in(1'b1)
  );

  integer pc = 0;
  task automatic put(input [31:0] instr);
    dut.rom.rom[pc] = instr;
    pc = pc + 1;
  endtask

  function automatic [31:0] r(input [6:0] f7, input [2:0] f3, input [4:0] rd, rs1, rs2);
    r = {f7, rs2, rs1, f3, rd, 7'b0110011};
  endfunction
  function automatic [31:0] i(input [2:0] f3, input [4:0] rd, rs1, input [11:0] imm);
    i = {imm, rs1, f3, rd, 7'b0010011};
  endfunction
  function automatic [31:0] load(input [2:0] f3, input [4:0] rd, rs1, input [11:0] imm);
    load = {imm, rs1, f3, rd, 7'b0000011};
  endfunction
  function automatic [31:0] store(input [2:0] f3, input [4:0] rs2, rs1, input [11:0] imm);
    store = {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011};
  endfunction
  // Branch forward by 8 bytes: skips the next instruction when taken.
  function automatic [31:0] skip(input [2:0] f3, input [4:0] rs1, rs2);
    skip = {7'd0, rs2, rs1, f3, 5'b01000, 7'b1100011};
  endfunction

  task automatic expect_reg(input integer n, input [31:0] value, input string name);
    if (dut.cpu.rf.x[n] !== value) $fatal(1, "%s: x%0d=%h, expected %h", name, n, dut.cpu.rf.x[n], value);
  endtask

  localparam [31:0] FAIL = 32'h001f8f93;  // addi x31, x31, 1

  initial begin
    #1;
    for (int k = 0; k < 4096; k++) dut.rom.rom[k] = 32'h00000013;  // NOP

    put({20'h20000, 5'd1, 7'b0110111});  // lui x1, 0x20000 (RAM)
    put(i(3'b000, 2, 0, -12'sd8));  // x2 = -8
    put(i(3'b000, 3, 0, 12'd13));  // x3 = 13

    // Register-register ALU
    put(r(7'h20, 3'b000, 4, 3, 2));  // sub  x4  = 13 - (-8)
    put(r(7'h00, 3'b111, 5, 2, 3));  // and  x5
    put(r(7'h00, 3'b110, 6, 2, 3));  // or   x6
    put(r(7'h00, 3'b100, 7, 2, 3));  // xor  x7
    put(r(7'h00, 3'b001, 8, 2, 3));  // sll  x8  = -8 << 13
    put(r(7'h00, 3'b101, 9, 2, 3));  // srl  x9  = -8 >> 13
    put(r(7'h20, 3'b101, 10, 2, 3));  // sra  x10 = -8 >>> 13
    put(r(7'h00, 3'b010, 11, 2, 3));  // slt  x11 = -8 < 13
    put(r(7'h00, 3'b011, 12, 2, 3));  // sltu x12 = 0xfffffff8 < 13

    // Register-immediate ALU
    put(i(3'b100, 13, 3, 12'd6));  // xori  x13
    put(i(3'b110, 14, 3, 12'd2));  // ori   x14
    put(i(3'b010, 15, 2, 12'd0));  // slti  x15
    put(i(3'b011, 16, 3, 12'd20));  // sltiu x16
    put(i(3'b001, 17, 3, 12'd4));  // slli  x17
    put(i(3'b101, 18, 2, 12'd28));  // srli  x18
    put(i(3'b101, 19, 2, 12'h401));  // srai  x19

    // Byte and halfword memory access
    put(store(3'b000, 2, 1, 12'd0));  // sb  x2, 0(x1)
    put(store(3'b001, 2, 1, 12'd4));  // sh  x2, 4(x1)
    put(load(3'b000, 20, 1, 12'd0));  // lb  x20
    put(load(3'b100, 21, 1, 12'd0));  // lbu x21
    put(load(3'b001, 22, 1, 12'd4));  // lh  x22
    put(load(3'b101, 23, 1, 12'd4));  // lhu x23

    // Every branch is taken and skips FAIL; x31 must stay zero.
    put(skip(3'b000, 3, 3));  put(FAIL);  // beq  13 == 13
    put(skip(3'b001, 2, 3));  put(FAIL);  // bne  -8 != 13
    put(skip(3'b100, 2, 3));  put(FAIL);  // blt  -8 < 13
    put(skip(3'b101, 3, 2));  put(FAIL);  // bge  13 >= -8
    put(skip(3'b110, 3, 2));  put(FAIL);  // bltu 13 < 0xfffffff8
    put(skip(3'b111, 2, 3));  put(FAIL);  // bgeu 0xfffffff8 >= 13

    // auipc + jalr: jump over FAIL, link = auipc address + 8
    put({20'd0, 5'd24, 7'b0010111});  // auipc x24, 0
    put({12'd12, 5'd24, 3'b000, 5'd25, 7'b1100111});  // jalr x25, 12(x24)
    put(FAIL);

    put(i(3'b000, 0, 0, 12'd5));  // addi x0, x0, 5 (ignored)
    put(i(3'b000, 26, 0, 12'd0));  // x26 = x0
    put(32'h0000006f);  // j .

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1;
    repeat (200) @(posedge clk);

    expect_reg(4, 32'd21, "sub");
    expect_reg(5, 32'd8, "and");
    expect_reg(6, 32'hfffffffd, "or");
    expect_reg(7, 32'hfffffff5, "xor");
    expect_reg(8, 32'hffff0000, "sll");
    expect_reg(9, 32'h0007ffff, "srl");
    expect_reg(10, 32'hffffffff, "sra");
    expect_reg(11, 32'd1, "slt");
    expect_reg(12, 32'd0, "sltu");
    expect_reg(13, 32'd11, "xori");
    expect_reg(14, 32'd15, "ori");
    expect_reg(15, 32'd1, "slti");
    expect_reg(16, 32'd1, "sltiu");
    expect_reg(17, 32'd208, "slli");
    expect_reg(18, 32'h0000000f, "srli");
    expect_reg(19, 32'hfffffffc, "srai");
    expect_reg(20, 32'hfffffff8, "lb");
    expect_reg(21, 32'h000000f8, "lbu");
    expect_reg(22, 32'hfffffff8, "lh");
    expect_reg(23, 32'h0000fff8, "lhu");
    expect_reg(31, 32'd0, "branches and jalr");
    expect_reg(25, dut.cpu.rf.x[24] + 8, "jalr link");
    expect_reg(26, 32'd0, "x0 stays zero");

    $display("cpu_isa_tb: PASS");
    $finish;
  end
endmodule
