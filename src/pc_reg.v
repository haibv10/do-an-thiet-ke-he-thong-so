module pc_reg (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        stall,
  input  wire [31:0] pc_next,
  output reg  [31:0] pc
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc <= 32'h00000000;
    else if (!stall)
      pc <= pc_next;
  end
endmodule
