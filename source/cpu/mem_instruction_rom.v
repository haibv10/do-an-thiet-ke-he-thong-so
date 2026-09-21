// 8 KB instruction ROM. Reads are registered so the tool infers BSRAM instead
// of logic. HEX_PATH resolves against the working directory, which both the
// simulation and synthesis flows set to the repository root.
module mem_instruction_rom #(
  parameter HEX_PATH = "rom/firmware.hex"
) (
  input  wire        clk,
  input  wire [31:0] a,
  output reg  [31:0] rd,
  // Second read port. Loads reach .rodata and the load image of .data through
  // it, since the linker places both in ROM.
  input  wire [31:0] a_data,
  output reg  [31:0] rd_data
);
  reg [31:0] rom [0:2047];
  integer index;

  initial begin
    // Words past the end of the image must read as zero rather than x, or a
    // stray load poisons the pipeline in simulation. Only simulation needs it:
    // make_hex.py pads the image to the full depth, so synthesis always has
    // every word defined, and GowinSynthesis refuses to unroll a loop of more
    // than 2000 iterations.
    // synthesis translate_off
    for (index = 0; index < 2048; index = index + 1) begin
      rom[index] = 32'd0;
    end
    // synthesis translate_on
    $readmemh(HEX_PATH, rom);
  end

  // Falling edge, so the word is settled before the next rising edge captures it.
  always @(negedge clk) begin
    rd      <= rom[a[12:2]];
    rd_data <= rom[a_data[12:2]];
  end
endmodule
