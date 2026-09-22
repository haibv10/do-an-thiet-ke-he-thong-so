// Reset bridge: asserts as soon as the pin goes low, releases only in step with
// the clock.
//
// rst_n comes straight off a mechanical button. Feeding its rising edge to the
// asynchronous reset pin of every flop in the design leaves the release time
// unrelated to the clock, so recovery and removal cannot be met and different
// flops can leave reset on different cycles. Holding the pipeline in an
// inconsistent state that way is indistinguishable from an RTL fault.
module reset_sync #(
  parameter integer STAGES = 2
) (
  input  wire clk,
  input  wire rst_n_in,
  output wire rst_n_out
);
  reg [STAGES-1:0] chain;

  always @(posedge clk or negedge rst_n_in) begin
    if (!rst_n_in) begin
      chain <= {STAGES{1'b0}};
    end else begin
      chain <= {chain[STAGES-2:0], 1'b1};
    end
  end

  assign rst_n_out = chain[STAGES-1];
endmodule
