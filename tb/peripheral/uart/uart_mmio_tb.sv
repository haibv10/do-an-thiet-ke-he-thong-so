`timescale 1ns / 1ps

// UART registers: TX sends one byte; RX receives one byte and the CPU reads it.
module uart_mmio_tb;
  localparam integer BIT = 8;  // short bit time for simulation

  logic clk = 0, rst_n = 0, we = 0, re = 0, rx = 1;
  logic [31:0] a = 0, wd = 0;
  wire [31:0] rd;
  wire tx;
  logic [7:0] received;
  always #5 clk = ~clk;

  uart_mmio #(.CLKS_PER_BIT(BIT)) dut (.*);

  initial #100_000 $fatal(1, "timeout");

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;

    // TX: write 0x35 to DATA (0x00) and capture it on the tx pin.
    a = 32'h00; wd = 32'h35; we = 1;
    @(negedge clk) we = 0;
    @(negedge tx);
    repeat (BIT + BIT / 2) @(posedge clk);
    for (int b = 0; b < 8; b++) begin
      received[b] = tx;
      repeat (BIT) @(posedge clk);
    end
    if (received !== 8'h35) $fatal(1, "TX sent %h, expected 35", received);

    // RX: drive 0xA7 on rx, then STATUS (0x04) bit 1 = data valid, RX (0x08) = byte.
    rx = 0;
    repeat (BIT) @(negedge clk);
    for (int b = 0; b < 8; b++) begin
      rx = 8'ha7 >> b;
      repeat (BIT) @(negedge clk);
    end
    rx = 1;
    repeat (2 * BIT) @(negedge clk);

    a = 32'h04; #1;
    if (rd[1] !== 1) $fatal(1, "RX valid not set, status=%h", rd);
    a = 32'h08; #1;
    if (rd !== 32'ha7) $fatal(1, "RX data=%h, expected a7", rd);
    re = 1;  // reading RX pops the byte
    @(negedge clk) re = 0;
    a = 32'h04; #1;
    if (rd[1] !== 0) $fatal(1, "RX valid not cleared after read");

    $display("uart_mmio_tb: PASS");
    $finish;
  end
endmodule
