module core_regfile (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [ 4:0] rs1,
  input  wire [ 4:0] rs2,
  input  wire [ 4:0] rd,
  input  wire [31:0] wd,
  output wire [31:0] rd1,
  output wire [31:0] rd2
);

  reg     [31:0] x [31:1];
  integer        i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 1; i < 32; i = i + 1) begin
        x[i] <= 32'd0;
      end
    end else if (we && (rd != 5'd0)) begin
      x[rd] <= wd;
    end
  end

  wire bypass_rs1 = we && (rd != 5'd0) && (rd == rs1);
  wire bypass_rs2 = we && (rd != 5'd0) && (rd == rs2);

  assign rd1 = (rs1 == 5'd0) ? 32'd0 : (bypass_rs1 ? wd : x[rs1]);
  assign rd2 = (rs2 == 5'd0) ? 32'd0 : (bypass_rs2 ? wd : x[rs2]);

endmodule
