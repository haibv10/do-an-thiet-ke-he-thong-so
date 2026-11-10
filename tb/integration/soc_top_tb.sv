`timescale 1ns / 1ps

// CPU drives peripherals through MMIO: LED on, UART sends 'H', then echoes one byte.
module soc_top_tb;
  localparam integer BIT = 234;  // clocks per UART bit at 115200 baud

  logic clk = 0, rst_n = 0, uart_rx_in = 1;
  wire led_out, uart_tx_out;
  logic [7:0] received;
  always #18.5 clk = ~clk;

  soc_top dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .led_out    (led_out),
    .uart_rx_in (uart_rx_in),
    .uart_tx_out(uart_tx_out)
  );

  task automatic uart_send(input [7:0] value);
    uart_rx_in = 0;
    repeat (BIT) @(negedge clk);
    for (int b = 0; b < 8; b++) begin
      uart_rx_in = value[b];
      repeat (BIT) @(negedge clk);
    end
    uart_rx_in = 1;
    repeat (BIT) @(negedge clk);
  endtask

  task automatic uart_receive(output [7:0] value);
    @(negedge uart_tx_out);
    repeat (BIT + BIT / 2) @(posedge clk);
    for (int b = 0; b < 8; b++) begin
      value[b] = uart_tx_out;
      repeat (BIT) @(posedge clk);
    end
  endtask

  initial #5_000_000 $fatal(1, "timeout");

  initial begin
    #1;
    for (int k = 0; k < 4096; k++) dut.rom.rom[k] = 32'h00000013;  // NOP
    dut.rom.rom[0]  = 32'h400000b7;  // lui  x1, 0x40000      GPIO
    dut.rom.rom[1]  = 32'h00100113;  // addi x2, x0, 1
    dut.rom.rom[2]  = 32'h0020a023;  // sw   x2, 0(x1)        LED on
    dut.rom.rom[3]  = 32'h500001b7;  // lui  x3, 0x50000      UART
    dut.rom.rom[4]  = 32'h04800213;  // addi x4, x0, 'H'
    dut.rom.rom[5]  = 32'h0041a023;  // sw   x4, 0(x3)        send 'H'
    dut.rom.rom[6]  = 32'h0041a283;  // lw   x5, 4(x3)        status
    dut.rom.rom[7]  = 32'h0022f293;  // andi x5, x5, 2        RX valid
    dut.rom.rom[8]  = 32'hfe028ce3;  // beqz x5, -8
    dut.rom.rom[9]  = 32'h0081a303;  // lw   x6, 8(x3)        RX data
    dut.rom.rom[10] = 32'h0061a023;  // sw   x6, 0(x3)        echo
    dut.rom.rom[11] = 32'h0000006f;  // j .

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1;

    uart_receive(received);
    if (led_out !== 1) $fatal(1, "LED not on");
    if (received !== "H") $fatal(1, "UART sent %h, expected 'H'", received);

    fork
      uart_send(8'h6b);
      uart_receive(received);
    join
    if (received !== 8'h6b) $fatal(1, "UART echo %h, expected 6b", received);

    $display("soc_top_tb: PASS");
    $finish;
  end
endmodule
