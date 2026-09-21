`timescale 1ns/1ps

module cpu_uart_hex_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire led_out;
  wire uart_tx_out;
  integer index;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out)
  );

  function automatic logic [31:0] encode_b(
    input logic [12:0] immediate,
    input logic [4:0] rs2,
    input logic [4:0] rs1
  );
    encode_b = {immediate[12], immediate[10:5], rs2, rs1, 3'b001,
                immediate[4:1], immediate[11], 7'b1100011};
  endfunction

  initial begin
    #1;
    for (index = 0; index < 1024; index = index + 1)
      dut.rom.rom[index] = 32'h0000_0013;

    dut.rom.rom[0] = 32'h00e0_0793; // addi x15, x0, 14
    dut.rom.rom[1] = 32'h00a7_b713; // sltiu x14, x15, 10
    dut.rom.rom[2] = 32'h0377_8993; // addi x19, x15, 55
    dut.rom.rom[3] = 32'h0007_0463; // beq x14, x0, +8
    dut.rom.rom[4] = 32'h0307_8993; // addi x19, x15, 48
    dut.rom.rom[5] = 32'h0070_0793; // addi x15, x0, 7
    dut.rom.rom[6] = 32'h00a7_b713; // sltiu x14, x15, 10
    dut.rom.rom[7] = 32'h0377_8a13; // addi x20, x15, 55
    dut.rom.rom[8] = 32'h0007_0463; // beq x14, x0, +8
    dut.rom.rom[9] = 32'h0307_8a13; // addi x20, x15, 48
    dut.rom.rom[10] = 32'h0200_0413; // addi x8, x0, 32
    dut.rom.rom[11] = 32'h0280_0a93; // addi x21, x0, 40
    dut.rom.rom[12] = 32'h0014_0413; // addi x8, x8, 1
    dut.rom.rom[13] = encode_b(13'h1ffc, 5'd21, 5'd8); // bne x8, x21, -4
    dut.rom.rom[14] = 32'h0000_006f; // jal x0, 0

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    repeat (100) @(posedge clk);

    if (dut.rf.x[19] !== 32'd69 || dut.rf.x[20] !== 32'd55 ||
        dut.rf.x[8] !== 32'd40)
      $fatal(1, "hex branch or address loop: E=%h 7=%h address=%h",
             dut.rf.x[19], dut.rf.x[20], dut.rf.x[8]);
    $display("cpu_uart_hex_tb: PASS");
    $finish;
  end
endmodule
