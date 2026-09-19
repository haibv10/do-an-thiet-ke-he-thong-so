module dmem (
  input  wire        clk,
  input  wire [3:0]  we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output reg  [31:0] rd
);
  reg [31:0] ram [0:1023];
  wire [9:0] word_addr = a[11:2];

  // Falling edge, so a load result is settled before the rising edge that
  // captures it into MEM/WB.
  always @(negedge clk) begin
    if (we[0]) ram[word_addr][7:0]   <= wd[7:0];
    if (we[1]) ram[word_addr][15:8]  <= wd[15:8];
    if (we[2]) ram[word_addr][23:16] <= wd[23:16];
    if (we[3]) ram[word_addr][31:24] <= wd[31:24];

    rd <= ram[word_addr];
  end
endmodule
