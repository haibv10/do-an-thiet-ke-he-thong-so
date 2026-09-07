`timescale 1ns/1ps

module uart_rx_tb;
  localparam integer CLKS_PER_BIT = 8;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic rx = 1'b1;
  logic clear = 1'b0;
  logic [7:0] data;
  logic valid;
  integer bit_index;

  always #5 clk = ~clk;

  uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) dut (.*);

  task automatic send_byte(input logic [7:0] value, input logic stop_bit);
    @(negedge clk) rx = 1'b0;
    repeat (CLKS_PER_BIT) @(negedge clk);
    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
      rx = value[bit_index];
      repeat (CLKS_PER_BIT) @(negedge clk);
    end
    rx = stop_bit;
    repeat (CLKS_PER_BIT) @(negedge clk);
    rx = 1'b1;
  endtask

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    send_byte(8'ha5, 1'b1);
    repeat (3) @(posedge clk);
    if (!valid || data !== 8'ha5) $fatal(1, "receive data=%h valid=%b", data, valid);

    @(negedge clk) clear = 1'b1;
    @(negedge clk) clear = 1'b0;
    if (valid) $fatal(1, "clear valid");

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
    if (!valid || data !== 8'h5a) $fatal(1, "receive after framing error");

    $display("uart_rx_tb: PASS");
    $finish;
  end
endmodule
