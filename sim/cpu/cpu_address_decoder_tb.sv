`timescale 1ns/1ps

// The decoder is what turns an ordinary load or store into a peripheral access,
// so every region has to select exactly one target and nothing else.
module cpu_address_decoder_tb;
  logic [31:0] addr = 32'd0;
  logic [3:0]  we_mask = 4'b0000;
  wire  [3:0]  we_dmem;
  wire         we_gpio, we_uart, we_spi;
  logic [31:0] rd_rom  = 32'h0000_0000;
  logic [31:0] rd_dmem = 32'h1111_1111;
  logic [31:0] rd_gpio = 32'h2222_2222;
  logic [31:0] rd_uart = 32'h3333_3333;
  logic [31:0] rd_spi  = 32'h5555_5555;
  wire  [31:0] rd_out;

  cpu_address_decoder dut (.*);

  task automatic expect_read(
    input logic [31:0] address,
    input logic [31:0] value,
    input string label
  );
    begin
      addr = address;
      #1;
      if (rd_out !== value)
        $fatal(1, "%s: read from %h = %h, expected %h",
               label, address, rd_out, value);
    end
  endtask

  task automatic expect_write(
    input logic [31:0] address,
    input logic [3:0] dmem_en,
    input logic gpio_en,
    input logic uart_en,
    input logic spi_en,
    input string label
  );
    begin
      addr = address;
      we_mask = 4'b1111;
      #1;
      if (we_dmem !== dmem_en || we_gpio !== gpio_en ||
          we_uart !== uart_en || we_spi !== spi_en)
        $fatal(1, "%s: write to %h gave mem_data_ram=%b gpio_mmio=%b uart=%b spi=%b",
               label, address, we_dmem, we_gpio, we_uart, we_spi);
      we_mask = 4'b0000;
    end
  endtask

  initial begin
    rd_rom = 32'h0000_0000;

    // Each region returns its own source and nothing else.
    rd_rom = 32'h0BAD_C0DE;
    expect_read(32'h0000_0010, 32'h0BAD_C0DE, "ROM window");
    expect_read(32'h2000_0000, 32'h1111_1111, "DMEM");
    expect_read(32'h4000_0000, 32'h2222_2222, "GPIO");
    expect_read(32'h5000_0000, 32'h3333_3333, "UART");
    expect_read(32'h7000_0000, 32'h5555_5555, "SPI");

    // Only addr[31:28] selects, so the offset within a region is irrelevant here.
    expect_read(32'h2FFF_FFFC, 32'h1111_1111, "DMEM at the top of its region");

    // Unmapped regions read as zero rather than floating.
    expect_read(32'h1000_0000, 32'd0, "unmapped 0x1");
    expect_read(32'h3000_0000, 32'd0, "unmapped 0x3");
    expect_read(32'h6000_0000, 32'd0, "unmapped 0x6");
    expect_read(32'h8000_0000, 32'd0, "unmapped 0x8");
    expect_read(32'hF000_0000, 32'd0, "unmapped 0xF");

    // RAM takes the full byte mask; peripherals take a single enable.
    expect_write(32'h2000_0000, 4'b1111, 1'b0, 1'b0, 1'b0, "store to DMEM");
    expect_write(32'h4000_0000, 4'b0000, 1'b1, 1'b0, 1'b0, "store to GPIO");
    expect_write(32'h5000_0000, 4'b0000, 1'b0, 1'b1, 1'b0, "store to UART");
    expect_write(32'h7000_0000, 4'b0000, 1'b0, 1'b0, 1'b1, "store to SPI");

    // The ROM window is read only: a store there must reach nothing at all.
    expect_write(32'h0000_0000, 4'b0000, 1'b0, 1'b0, 1'b0, "store into ROM");
    expect_write(32'h3000_0000, 4'b0000, 1'b0, 1'b0, 1'b0, "store to unmapped 0x3");

    // The byte mask passes through to RAM unchanged, so SB and SH still work.
    addr = 32'h2000_0001;
    we_mask = 4'b0010;
    #1;
    if (we_dmem !== 4'b0010) $fatal(1, "byte mask not forwarded: %b", we_dmem);

    // A masked store still must not reach a peripheral that wants bit 0 only.
    addr = 32'h4000_0000;
    we_mask = 4'b1110;
    #1;
    if (we_gpio !== 1'b0)
      $fatal(1, "GPIO enabled by a mask with bit 0 clear");

    $display("cpu_address_decoder_tb: PASS");
    $finish;
  end
endmodule
