module imem (
  input  wire        clk, // Thêm cổng clk
  input  wire [31:0] a,
  output reg  [31:0] rd   // Đổi thành reg
);
  // 1024 words = 4KB, đủ rộng rãi cho code C
  reg [31:0] rom [0:1023];

  initial begin
    $readmemh("src/firmware.hex", rom);
  end

  // Đọc đồng bộ ở cạnh xuống để suy diễn thành BSRAM
  always @(negedge clk) begin
    rd <= rom[a[11:2]];
  end
endmodule
