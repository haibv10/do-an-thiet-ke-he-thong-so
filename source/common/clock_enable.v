module clock_enable #(
  parameter integer divider = 27
) (
  input  wire clk,
  input  wire rst_n,
  output reg  tick
);
  integer count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
      tick  <= 1'b0;
    end else if (count == divider - 1) begin
      count <= 0;
      tick  <= 1'b1;
    end else begin
      count <= count + 1;
      tick  <= 1'b0;
    end
  end
endmodule
