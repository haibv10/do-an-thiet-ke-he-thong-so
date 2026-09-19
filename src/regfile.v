module regfile (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [4:0]  rs1,
  input  wire [4:0]  rs2,
  input  wire [4:0]  rd,
  input  wire [31:0] wd,
  output wire [31:0] rd1,
  output wire [31:0] rd2
);

  // x0 reads as zero by construction below, so it needs no storage.
  reg [31:0] x [31:1];
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 1; i < 32; i = i + 1) begin
        x[i] <= 32'd0;
      end
    end else if (we && (rd != 5'd0)) begin
      x[rd] <= wd;
    end
  end

  // Write-first: the forwarding unit only reaches back two instructions, so
  // without returning the pending write data here a dependency three
  // instructions apart would read the stale value.
  wire bypass_rs1 = we && (rd != 5'd0) && (rd == rs1);
  wire bypass_rs2 = we && (rd != 5'd0) && (rd == rs2);

  assign rd1 = (rs1 == 5'd0) ? 32'd0 : (bypass_rs1 ? wd : x[rs1]);
  assign rd2 = (rs2 == 5'd0) ? 32'd0 : (bypass_rs2 ? wd : x[rs2]);

endmodule
