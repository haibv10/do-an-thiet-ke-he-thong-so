module cpu_address_decoder (
  input wire [31:0] addr,
  input wire [3:0] we_mask,
  input wire re,
  output wire [3:0] we_dmem,
  output wire we_gpio, we_uart, we_i2c, we_spi, we_dht,
  output wire re_uart, re_dht,
  input wire [31:0] rd_rom, rd_dmem, rd_gpio, rd_uart, rd_i2c, rd_spi, rd_dht,
  output reg [31:0] rd_out
);
  wire sel_rom = addr < 32'h00004000;
  wire sel_ram = addr >= 32'h20000000 && addr < 32'h20002000;
  // Peripheral registers support aligned 32-bit accesses and low-byte stores.
  wire aligned = addr[1:0] == 2'b00;
  wire sel_gpio = aligned && addr == 32'h40000000;
  wire sel_uart = aligned && addr >= 32'h50000000 && addr < 32'h50000010;
  wire sel_i2c = aligned && addr >= 32'h60000000 && addr < 32'h6000000c;
  wire sel_spi = aligned && addr >= 32'h70000000 && addr < 32'h7000000c;
  wire sel_dht = aligned && addr >= 32'h80000000 && addr < 32'h80000008;

  assign we_dmem = sel_ram ? we_mask : 4'b0000;
  assign we_gpio = sel_gpio && we_mask[0];
  assign we_uart = sel_uart && we_mask[0];
  assign we_i2c = sel_i2c && we_mask[0];
  assign we_spi = sel_spi && we_mask[0];
  assign we_dht = sel_dht && we_mask[0];
  assign re_uart = re && sel_uart;
  assign re_dht = re && sel_dht;

  // Unmapped reads return zero and writes have no effect; no access trap.
  always @(*) begin
    rd_out = 32'd0;
    if (sel_rom) rd_out = rd_rom;
    else if (sel_ram) rd_out = rd_dmem;
    else if (sel_gpio) rd_out = rd_gpio;
    else if (sel_uart) rd_out = rd_uart;
    else if (sel_i2c) rd_out = rd_i2c;
    else if (sel_spi) rd_out = rd_spi;
    else if (sel_dht) rd_out = rd_dht;
  end
endmodule
