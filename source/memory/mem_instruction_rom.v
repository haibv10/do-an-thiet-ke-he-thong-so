module mem_instruction_rom #(
  parameter HEX_PATH = "rom/firmware.hex"
) (
  input  wire        clk,
  input  wire [31:0] a,
  output reg  [31:0] rd,

  input  wire [31:0] a_data,
  output reg  [31:0] rd_data
);
  reg     [31:0] rom   [0:2047];
  integer        index;

  initial begin

    // synthesis translate_off
    for (index = 0; index < 2048; index = index + 1) begin
      rom[index] = 32'd0;
    end
    // synthesis translate_on
    $readmemh(HEX_PATH, rom);
  end

  always @(negedge clk) begin
    rd      <= rom[a[12:2]];
    rd_data <= rom[a_data[12:2]];
  end
endmodule
