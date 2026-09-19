// 4 KB instruction ROM. Reads are registered so the tool infers BSRAM instead
// of logic. HEX_PATH resolves against the working directory, which both the
// simulation and synthesis flows set to the repository root.
module imem #(
  parameter HEX_PATH = "sw/firmware.hex"
) (
  input  wire        clk,
  input  wire [31:0] a,
  output reg  [31:0] rd,
  // Second read port. Loads reach .rodata and the load image of .data through
  // it, since the linker places both in ROM.
  input  wire [31:0] a_data,
  output reg  [31:0] rd_data
);
  reg [31:0] rom [0:1023];
  integer index;

  initial begin
    // Words past the end of the image must read as zero rather than x, or a
    // stray load poisons the pipeline in simulation.
    for (index = 0; index < 1024; index = index + 1) begin
      rom[index] = 32'd0;
    end
    $readmemh(HEX_PATH, rom);
  end

  // Falling edge, so the word is settled before the next rising edge captures it.
  always @(negedge clk) begin
    rd      <= rom[a[11:2]];
    rd_data <= rom[a_data[11:2]];
  end
endmodule
