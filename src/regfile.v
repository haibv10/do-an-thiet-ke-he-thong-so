module regfile (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,     // write enable
  input  wire [4:0]  rs1,    // source register 1 index
  input  wire [4:0]  rs2,    // source register 2 index
  input  wire [4:0]  rd,     // destination register index
  input  wire [31:0] wd,     // write data
  output wire [31:0] rd1,    // read data from rs1
  output wire [31:0] rd2     // read data from rs2
);

  // 31 storage slots, x1 through x31. x0 needs none because it is hardwired to zero.
  reg [31:0] x [31:1];
  integer i;

  // Write port, on the rising clock edge
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset clears all 31 slots
      for (i = 1; i < 32; i = i + 1) begin
        x[i] <= 32'd0;
      end
    end else if (we && (rd != 5'd0)) begin
      // Write only when enabled and the destination is not x0
      x[rd] <= wd;
    end
  end

  // Read ports are combinational. Note: there is no write-first bypass, so an
  // instruction in ID reads the old value while WB writes in the same cycle.
  assign rd1 = (rs1 == 5'd0) ? 32'd0 : x[rs1];
  assign rd2 = (rs2 == 5'd0) ? 32'd0 : x[rs2];

endmodule
