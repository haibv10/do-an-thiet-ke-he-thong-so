`timescale 1ns/1ps

module uart_rx_tb;
  localparam integer CLKS_PER_BIT = 8;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic rx = 1'b1;
  logic pop = 1'b0;
  logic clear_overrun = 1'b0;
  logic [7:0] data;
  logic valid;
  logic overrun;
  logic [4:0] level;
  integer bit_index;

  always #5 clk = ~clk;

  uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT),
    .FIFO_DEPTH(16)
  ) dut (.*);

  task automatic send_byte(input logic [7:0] value, input logic stop_bit);
    integer data_bit;
    @(negedge clk) rx = 1'b0;
    repeat (CLKS_PER_BIT) @(negedge clk);
    for (data_bit = 0; data_bit < 8; data_bit = data_bit + 1) begin
      rx = value[data_bit];
      repeat (CLKS_PER_BIT) @(negedge clk);
    end
    rx = stop_bit;
    repeat (CLKS_PER_BIT) @(negedge clk);
    rx = 1'b1;
  endtask

  task automatic pop_byte(input logic [7:0] expected);
    if (!valid || data !== expected)
      $fatal(1, "FIFO head=%h valid=%b, expected %h", data, valid, expected);
    @(negedge clk) pop = 1'b1;
    @(negedge clk) pop = 1'b0;
  endtask

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    send_byte(8'ha5, 1'b1);
    repeat (3) @(posedge clk);
    if (!valid || data !== 8'ha5 || level !== 5'd1)
      $fatal(1, "receive data=%h valid=%b level=%d", data, valid, level);

    send_byte(8'hc3, 1'b1);
    repeat (3) @(posedge clk);
    if (level !== 5'd2) $fatal(1, "FIFO level=%d", level);
    pop_byte(8'ha5);
    pop_byte(8'hc3);
    if (valid || level !== 5'd0) $fatal(1, "FIFO did not empty");

    @(negedge clk) rx = 1'b0;
    repeat (2) @(negedge clk);
    rx = 1'b1;
    repeat (CLKS_PER_BIT) @(posedge clk);
    if (valid) $fatal(1, "false start accepted");

    send_byte(8'h3c, 1'b0);
    repeat (3) @(posedge clk);
    if (valid) $fatal(1, "invalid stop bit accepted");

    send_byte(8'h5a, 1'b1);
    repeat (3) @(posedge clk);
    pop_byte(8'h5a);

    for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
      send_byte(bit_index, 1'b1);
    repeat (3) @(posedge clk);
    if (level !== 5'd16 || data !== 8'h00)
      $fatal(1, "FIFO full level=%d head=%h", level, data);

    send_byte(8'hff, 1'b1);
    repeat (3) @(posedge clk);
    if (!overrun || level !== 5'd16 || data !== 8'h00)
      $fatal(1, "FIFO overrun=%b level=%d head=%h", overrun, level, data);

    @(negedge clk) clear_overrun = 1'b1;
    @(negedge clk) clear_overrun = 1'b0;
    if (overrun) $fatal(1, "overrun did not clear");

    for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
      pop_byte(bit_index);
    if (valid || level !== 5'd0) $fatal(1, "FIFO did not drain");

    $display("uart_rx_tb: PASS");
    $finish;
  end
endmodule
