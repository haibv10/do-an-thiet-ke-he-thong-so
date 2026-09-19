module cpu_address_decoder (
  input  wire [31:0] addr,
  input  wire [3:0]  we_mask,  // 4-bit byte mask from the CPU
  output wire [3:0]  we_dmem,
  output wire        we_gpio,
  output wire        we_uart,
  output wire        we_i2c,
  input  wire [31:0] rd_rom,
  input  wire [31:0] rd_dmem,
  input  wire [31:0] rd_gpio,
  input  wire [31:0] rd_uart,
  input  wire [31:0] rd_i2c,
  output reg  [31:0] rd_out
);
  // Region 0x0 is the instruction ROM. It answers loads but has no write enable,
  // so a store there is simply dropped.
  // RAM takes the full 4-bit mask; peripherals only need bit 0 as an enable
  assign we_dmem = (addr[31:28] == 4'h2) ? we_mask : 4'b0000;
  assign we_gpio = (addr[31:28] == 4'h4) ? we_mask[0] : 1'b0;
  assign we_uart = (addr[31:28] == 4'h5) ? we_mask[0] : 1'b0;
  assign we_i2c  = (addr[31:28] == 4'h6) ? we_mask[0] : 1'b0;

  always @(*) begin
    case (addr[31:28])
      4'h0: rd_out = rd_rom;
      4'h2: rd_out = rd_dmem;
      4'h4: rd_out = rd_gpio;
      4'h5: rd_out = rd_uart;
      4'h6: rd_out = rd_i2c;
      default: rd_out = 32'd0;
    endcase
  end
endmodule
