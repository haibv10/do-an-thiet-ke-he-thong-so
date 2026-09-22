module gpio_mmio (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output wire [31:0] rd,
  output reg         led
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led <= 1'b0;
    end else if (we && (a[7:0] == 8'h00)) begin
      led <= wd[0];
    end
  end

  assign rd = (a[7:0] == 8'h00) ? {31'd0, led} : 32'd0;

endmodule
