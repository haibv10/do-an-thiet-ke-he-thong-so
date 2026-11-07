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
