`timescale 1ns/1ps

module clock_enable_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic tick;
  integer tick_count = 0;

  always #5 clk = ~clk;
  always @(posedge tick) tick_count = tick_count + 1;

  clock_enable #(.divider(4)) dut (
    .clk(clk), .rst_n(rst_n), .tick(tick)
  );

  initial begin
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    repeat (13) @(posedge clk);
    if (tick_count != 3)
      $fatal(1, "expected three ticks, got %0d", tick_count);
    $display("clock_enable_tb: PASS");
    $finish;
  end
endmodule
