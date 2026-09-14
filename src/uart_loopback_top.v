module uart_loopback_top (
  input  wire clk,
  input  wire rst_n,
  output wire led_out,
  input  wire btn_in,
  input  wire uart_tx_out,
  output wire uart_rx_in
);

  // Exercise the alternate board UART direction without changing product constraints.
  assign uart_rx_in = uart_tx_out;
  assign led_out = 1'b0;

endmodule
