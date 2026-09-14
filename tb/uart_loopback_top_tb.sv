`timescale 1ns/1ps

module uart_loopback_top_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic led_out;
  logic btn_in = 1'b0;
  logic uart_tx_out = 1'b1;
  logic uart_rx_in;

  always #5 clk = ~clk;

  uart_loopback_top dut (.*);

  initial begin
    #1;
    if (uart_rx_in !== 1'b1) $fatal(1, "idle loopback");
    uart_tx_out = 1'b0;
    #1;
    if (uart_rx_in !== 1'b0) $fatal(1, "low loopback");
    uart_tx_out = 1'b1;
    #1;
    if (uart_rx_in !== 1'b1) $fatal(1, "high loopback");
    if (led_out !== 1'b0) $fatal(1, "diagnostic LED state");
    $display("uart_loopback_top_tb: PASS");
    $finish;
  end
endmodule
