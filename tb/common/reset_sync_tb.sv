`timescale 1ns / 1ps

module reset_sync_tb;
  localparam integer STAGES = 2;

  logic   clk = 1'b0;
  logic   rst_n_in = 1'b1;
  wire    rst_n_out;
  integer edges;

  always #5 clk = ~clk;

  reset_sync #(
    .STAGES(STAGES)
  ) dut (
    .clk      (clk),
    .rst_n_in (rst_n_in),
    .rst_n_out(rst_n_out)
  );

  initial begin

    @(negedge clk);
    #2;
    rst_n_in = 1'b0;
    #1;
    if (rst_n_out !== 1'b0) $fatal(1, "output = %b, should have fallen with the pin", rst_n_out);

    repeat (5) @(posedge clk);
    #1;
    if (rst_n_out !== 1'b0) $fatal(1, "output released while the pin is still low");

    @(negedge clk);
    rst_n_in = 1'b1;
    #1;
    if (rst_n_out !== 1'b0) $fatal(1, "output rose on the pin edge instead of a clock edge");

    for (edges = 1; edges <= STAGES; edges = edges + 1) begin
      @(posedge clk);
      #1;
      if (edges < STAGES && rst_n_out !== 1'b0)
        $fatal(1, "output rose after %0d of %0d clock edges", edges, STAGES);
    end
    if (rst_n_out !== 1'b1) $fatal(1, "output still low after %0d clock edges", STAGES);

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
