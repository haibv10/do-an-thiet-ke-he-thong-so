// Instruction memory: 4 KB ROM (1024 words), read synchronously so the tool infers BSRAM.
// HEX_PATH is relative to the simulation/synthesis working directory (repository root).
module imem #(
  parameter HEX_PATH = "sw/firmware.hex"
) (
  input  wire        clk,
  input  wire [31:0] a,
  output reg  [31:0] rd
);
  reg [31:0] rom [0:1023];

  initial begin
    $readmemh(HEX_PATH, rom);
  end

  // Read on the falling edge so data is ready before the next rising edge in IF
  always @(negedge clk) begin
    rd <= rom[a[11:2]];
  end
endmodule
