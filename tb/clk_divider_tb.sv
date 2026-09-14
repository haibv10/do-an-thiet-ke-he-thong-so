`timescale 1ns/1ps

module clk_divider_tb;
  logic clk = 1'b0;
  logic clk_1MHz;
  time previous_edge = 0;
  integer edge_count = 0;

  always #5 clk = ~clk;

  // A 100 MHz simulation clock divided to 10 MHz gives a 50 ns half-period.
  clk_divider #(
    .input_clk_freq(100_000_000),
    .output_clk_freq(10_000_000)
  ) dut (
    .clk,
    .clk_1MHz
  );

  always @(posedge clk_1MHz or negedge clk_1MHz) begin
    if (edge_count != 0 && ($time - previous_edge) != 50)
      $fatal(1, "expected a 50 ns output half-period, got %0t ns",
             $time - previous_edge);
    previous_edge = $time;
    edge_count = edge_count + 1;
  end

  initial begin
    wait (edge_count == 6);
    $display("clk_divider_tb: PASS");
    $finish;
  end
endmodule
