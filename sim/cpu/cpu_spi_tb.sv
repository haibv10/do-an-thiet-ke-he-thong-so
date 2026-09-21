`timescale 1ns/1ps

// The whole store-to-pin path: a store in MEM reaches the SPI region through
// the decoder, spi_mmio latches it, and the byte comes out on the pins with the
// data/command line in the state firmware set. The program is handwritten
// rather than the real firmware image because the ST7735 reset sequence spends
// hundreds of milliseconds in delay loops, which nothing here needs to prove.
module cpu_spi_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire led_out;
  wire uart_tx_out;
  tri1 i2c_sda;
  tri1 i2c_scl;
  wire spi_sck_out;
  wire spi_mosi_out;
  wire spi_cs_n_out;
  wire spi_dc_out;
  wire spi_rst_n_out;

  integer index;
  integer bit_count = 0;
  integer byte_count = 0;
  logic [7:0] shift = 8'd0;
  logic [7:0] seen_byte [0:3];
  logic       seen_dc   [0:3];

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out),
    .i2c_sda(i2c_sda), .i2c_scl(i2c_scl),
    .spi_sck_out(spi_sck_out), .spi_mosi_out(spi_mosi_out),
    .spi_cs_n_out(spi_cs_n_out), .spi_dc_out(spi_dc_out),
    .spi_rst_n_out(spi_rst_n_out)
  );

  // Sample on the rising edge, the way the panel does, and record the state of
  // dc for each completed byte.
  always @(posedge spi_sck_out) begin
    if (rst_n) begin
      shift = {shift[6:0], spi_mosi_out};
      bit_count = bit_count + 1;
      if (bit_count == 8) begin
        if (byte_count < 4) begin
          seen_byte[byte_count] = shift;
          seen_dc[byte_count] = spi_dc_out;
        end
        byte_count = byte_count + 1;
        bit_count = 0;
      end
    end
  end

  initial begin
    #4000000;
    $fatal(1, "timeout after %0d bytes", byte_count);
  end

  initial begin
    #1;
    for (index = 0; index < 1024; index = index + 1)
      dut.rom.rom[index] = 32'h0000_0013;

    // Select the panel in command mode, send 0x3a (COLMOD), poll busy, switch
    // to data mode, send 0x55, poll busy, then deselect.
    dut.rom.rom[0]  = 32'h7000_02b7; // lui  x5, 0x70000
    dut.rom.rom[1]  = 32'h0040_0313; // addi x6, x0, 4      cs_n=0 dc=0 rst_n=1
    dut.rom.rom[2]  = 32'h0062_a423; // sw   x6, 8(x5)
    dut.rom.rom[3]  = 32'h03a0_0313; // addi x6, x0, 0x3a
    dut.rom.rom[4]  = 32'h0062_a023; // sw   x6, 0(x5)
    dut.rom.rom[5]  = 32'h0042_a383; // lw   x7, 4(x5)
    dut.rom.rom[6]  = 32'h0013_f393; // andi x7, x7, 1
    dut.rom.rom[7]  = 32'hfe03_9ce3; // bne  x7, x0, -8
    dut.rom.rom[8]  = 32'h0060_0313; // addi x6, x0, 6      cs_n=0 dc=1 rst_n=1
    dut.rom.rom[9]  = 32'h0062_a423; // sw   x6, 8(x5)
    dut.rom.rom[10] = 32'h0550_0313; // addi x6, x0, 0x55
    dut.rom.rom[11] = 32'h0062_a023; // sw   x6, 0(x5)
    dut.rom.rom[12] = 32'h0042_a383; // lw   x7, 4(x5)
    dut.rom.rom[13] = 32'h0013_f393; // andi x7, x7, 1
    dut.rom.rom[14] = 32'hfe03_9ce3; // bne  x7, x0, -8
    dut.rom.rom[15] = 32'h0050_0313; // addi x6, x0, 5      cs_n=1 deselect
    dut.rom.rom[16] = 32'h0062_a423; // sw   x6, 8(x5)
    dut.rom.rom[17] = 32'h0000_006f; // jal  x0, 0

    // Reset must leave the panel deselected and held in reset before the CPU
    // has executed anything at all.
    repeat (2) @(posedge clk);
    #1;
    if (spi_cs_n_out !== 1'b1) $fatal(1, "cs_n = %b during reset", spi_cs_n_out);
    if (spi_rst_n_out !== 1'b0) $fatal(1, "panel rst_n = %b during reset", spi_rst_n_out);
    if (spi_sck_out !== 1'b0) $fatal(1, "sck = %b during reset", spi_sck_out);

    @(negedge clk) rst_n = 1'b1;

    wait (byte_count == 2);
    repeat (200) @(posedge clk);

    if (byte_count !== 2)
      $fatal(1, "%0d bytes on the wire, expected 2", byte_count);
    if (seen_byte[0] !== 8'h3a)
      $fatal(1, "first byte %h, expected 3a", seen_byte[0]);
    if (seen_dc[0] !== 1'b0)
      $fatal(1, "dc = %b for the command byte, expected 0", seen_dc[0]);
    if (seen_byte[1] !== 8'h55)
      $fatal(1, "second byte %h, expected 55", seen_byte[1]);
    if (seen_dc[1] !== 1'b1)
      $fatal(1, "dc = %b for the parameter byte, expected 1", seen_dc[1]);

    // The store that deselects only lands after the poll loop sees busy clear,
    // so cs_n going high proves firmware can frame a transaction.
    if (spi_cs_n_out !== 1'b1)
      $fatal(1, "cs_n = %b after the deselect store", spi_cs_n_out);
    if (spi_rst_n_out !== 1'b1)
      $fatal(1, "panel rst_n = %b after firmware released it", spi_rst_n_out);

    $display("cpu_spi_tb: PASS");
    $finish;
  end
endmodule
