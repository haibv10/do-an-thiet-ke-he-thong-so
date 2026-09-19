`timescale 1ns/1ps

// The reset bridge has to behave asymmetrically: assert the moment the pin
// drops, regardless of the clock, but release only on a clock edge.
module reset_sync_tb;
  localparam integer STAGES = 2;

  logic clk = 1'b0;
  logic rst_n_in = 1'b1;
  wire  rst_n_out;
  integer edges;

  always #5 clk = ~clk;

  reset_sync #(.STAGES(STAGES)) dut (
    .clk(clk), .rst_n_in(rst_n_in), .rst_n_out(rst_n_out)
  );

  initial begin
    // Assertion is asynchronous. Drop the pin midway between two clock edges;
    // the output must follow without waiting for one.
    @(negedge clk);
    #2;
    rst_n_in = 1'b0;
    #1;
    if (rst_n_out !== 1'b0)
      $fatal(1, "output = %b, should have fallen with the pin", rst_n_out);

    // It stays asserted for as long as the pin is low, however many edges pass.
    repeat (5) @(posedge clk);
    #1;
    if (rst_n_out !== 1'b0) $fatal(1, "output released while the pin is still low");

    // Release between clock edges: the output must not move until the chain has
    // clocked STAGES times.
    @(negedge clk);
    rst_n_in = 1'b1;
    #1;
    if (rst_n_out !== 1'b0)
      $fatal(1, "output rose on the pin edge instead of a clock edge");

    for (edges = 1; edges <= STAGES; edges = edges + 1) begin
      @(posedge clk);
      #1;
      if (edges < STAGES && rst_n_out !== 1'b0)
        $fatal(1, "output rose after %0d of %0d clock edges", edges, STAGES);
    end
    if (rst_n_out !== 1'b1)
      $fatal(1, "output still low after %0d clock edges", STAGES);

    // A second press must behave the same way, so the chain is not one-shot.
    @(posedge clk);
    #2;
    rst_n_in = 1'b0;
    #1;
    if (rst_n_out !== 1'b0) $fatal(1, "output did not fall on the second press");

    @(negedge clk);
    rst_n_in = 1'b1;
    repeat (STAGES) @(posedge clk);
    #1;
    if (rst_n_out !== 1'b1) $fatal(1, "output did not release on the second cycle");

    $display("reset_sync_tb: PASS");
    $finish;
  end
endmodule
