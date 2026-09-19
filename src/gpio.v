module gpio (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output wire [31:0] rd,
  output reg         led,
  input  wire        btn_in
);

  // Only the low 8 address bits are decoded as a register offset:
  //   a[7:0] == 8'h00 -> 0x40000000, LED
  //   a[7:0] == 8'h04 -> 0x40000004, button

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led <= 1'b0;
    end else if (we && (a[7:0] == 8'h00)) begin
      led <= wd[0];
    end
  end

  assign rd = (a[7:0] == 8'h00) ? {31'd0, led} :
        (a[7:0] == 8'h04) ? {31'd0, btn_in} : 32'd0;

endmodule
