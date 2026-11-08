`timescale 1ns / 1ps
module cpu_mmio_demo_tb;
  logic clk = 0, rst_n = 0, uart_rx_in = 1;
  wire uart_tx_out, led_out, spi_sck_out, spi_mosi_out, spi_cs_n_out;
  tri1 i2c_sda, i2c_scl;
  reg [7:0] spi_byte = 0;
  integer spi_bits = 0;
  always #18.5 clk = ~clk;
  soc_top #(.ROM_HEX_PATH("build/demo/firmware.hex")) dut (
    .clk(clk), .rst_n(rst_n), .uart_rx_in(uart_rx_in), .uart_tx_out(uart_tx_out),
    .led_out(led_out), .i2c_sda(i2c_sda), .i2c_scl(i2c_scl),
    .spi_sck_out(spi_sck_out), .spi_mosi_out(spi_mosi_out), .spi_cs_n_out(spi_cs_n_out)
  );
  i2c_register_slave_model #(.ADDRESS(7'h68)) rtc (.sda(i2c_sda), .scl(i2c_scl));
  always @(posedge spi_sck_out) begin
    if (spi_cs_n_out !== 0) $fatal(1, "SPI clock with CS inactive");
    spi_byte = {spi_byte[6:0], spi_mosi_out};
    spi_bits++;
  end
  task automatic expect_text(input string expected);
    reg [7:0] value;
    for (integer index = 0; index < expected.len(); index++) begin
      @(negedge uart_tx_out);
      repeat (234 + 117) @(negedge clk);
      for (integer bit_index = 0; bit_index < 8; bit_index++) begin
        value[bit_index] = uart_tx_out;
        repeat (234) @(negedge clk);
      end
      if (uart_tx_out !== 1) $fatal(1, "UART stop bit");
      if (value !== expected[index])
        $fatal(1, "UART byte %0d = %h, expected %h in %s", index, value, expected[index], expected);
    end
  endtask
  task automatic send_byte(input [7:0] value);
    @(negedge clk); uart_rx_in = 0;
    repeat (234) @(negedge clk);
    for (integer bit_index = 0; bit_index < 8; bit_index++) begin
      uart_rx_in = value[bit_index];
      repeat (234) @(negedge clk);
    end
    uart_rx_in = 1;
    repeat (234) @(negedge clk);
  endtask
  initial begin
    #100000000;
    $fatal(1, "MMIO demo timeout");
  end
  initial begin
    for (integer index = 0; index < 19; index++) rtc.regs[index] = 0;
    rtc.regs[0] = 8'h45; rtc.regs[1] = 8'h30; rtc.regs[2] = 8'h12;
    rtc.regs[3] = 8'h02; rtc.regs[4] = 8'h09; rtc.regs[5] = 8'h11; rtc.regs[6] = 8'h26;
    repeat (3) @(negedge clk); rst_n = 1;
    expect_text("RAM PASS\015\012I2C RTC 2026-11-09 12:30:45\015\012SPI TX OK\015\012MMIO DEMO READY: echo; r=RTC s=SPI l=LED\015\012");
    if (spi_bits !== 8 || spi_byte !== 0 || spi_cs_n_out !== 1)
      $fatal(1, "SPI NOP transfer incorrect");
    if (led_out !== 1) $fatal(1, "GPIO startup write");
    fork send_byte("Z"); expect_text("Z"); join
    fork send_byte("l"); expect_text("l"); join
    repeat (20) @(negedge clk);
    if (led_out !== 0) $fatal(1, "GPIO toggle command");
    $display("cpu_mmio_demo_tb: PASS (RAM, GPIO, I2C, SPI, UART echo)");
    $finish;
  end
endmodule
