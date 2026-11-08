`timescale 1ns / 1ps

module cpu_i2c_tb;
  logic   clk = 1'b0;
  logic   rst_n = 1'b0;
  wire    led_out;
  wire    uart_tx_out;
  tri1    i2c_sda;
  tri1    i2c_scl;
  wire    spi_sck_out;
  wire    spi_mosi_out;
  wire    spi_cs_n_out;
  wire    spi_dc_out;
  wire    spi_rst_n_out;

  integer index;

  always #18.5 clk = ~clk;

  soc_top dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .led_out      (led_out),
    .uart_rx_in   (1'b1),
    .uart_tx_out  (uart_tx_out),
    .i2c_sda      (i2c_sda),
    .i2c_scl      (i2c_scl),
    .spi_sck_out  (spi_sck_out),
    .spi_mosi_out (spi_mosi_out),
    .spi_cs_n_out (spi_cs_n_out),
    .spi_dc_out   (spi_dc_out),
    .spi_rst_n_out(spi_rst_n_out)
  );

  i2c_register_slave_model #(
    .ADDRESS(7'h68)
  ) slave (
    .sda(i2c_sda),
    .scl(i2c_scl)
  );

  initial begin
    #6000000;
    $fatal(1, "timeout, slave state %0d, x20=%h x21=%h", slave.state, dut.cpu.rf.x[20], dut.cpu.rf.x[21]);
  end

  initial begin
    #1;
    for (index = 0; index < 2048; index = index + 1) dut.rom.rom[index] = 32'h0000_0013;

    slave.regs[0] = 8'h45;
    slave.regs[1] = 8'h30;
    for (index = 2; index < 19; index = index + 1) slave.regs[index] = 8'h00;

    dut.rom.rom[0]  = 32'h6000_02b7;
    dut.rom.rom[1]  = 32'h1d00_0313;
    dut.rom.rom[2]  = 32'h0062_a023;
    dut.rom.rom[3]  = 32'h0042_a383;
    dut.rom.rom[4]  = 32'h0013_f393;
    dut.rom.rom[5]  = 32'hfe03_9ce3;
    dut.rom.rom[6]  = 32'h0000_0313;
    dut.rom.rom[7]  = 32'h0062_a023;
    dut.rom.rom[8]  = 32'h0042_a383;
    dut.rom.rom[9]  = 32'h0013_f393;
    dut.rom.rom[10] = 32'hfe03_9ce3;
    dut.rom.rom[11] = 32'h1d10_0313;
    dut.rom.rom[12] = 32'h0062_a023;
    dut.rom.rom[13] = 32'h0042_a383;
    dut.rom.rom[14] = 32'h0013_f393;
    dut.rom.rom[15] = 32'hfe03_9ce3;
    dut.rom.rom[16] = 32'h4000_0313;
    dut.rom.rom[17] = 32'h0062_a023;
    dut.rom.rom[18] = 32'h0042_a383;
    dut.rom.rom[19] = 32'h0013_f393;
    dut.rom.rom[20] = 32'hfe03_9ce3;
    dut.rom.rom[21] = 32'h0082_aa03;
    dut.rom.rom[22] = 32'h0000_1337;
    dut.rom.rom[23] = 32'he003_0313;
    dut.rom.rom[24] = 32'h0062_a023;
    dut.rom.rom[25] = 32'h0042_a383;
    dut.rom.rom[26] = 32'h0013_f393;
    dut.rom.rom[27] = 32'hfe03_9ce3;
    dut.rom.rom[28] = 32'h0082_aa83;
    dut.rom.rom[29] = 32'h0000_006f;

    repeat (2) @(posedge clk);
    #1;
    if (i2c_sda !== 1'b1 || i2c_scl !== 1'b1)
      $fatal(1, "bus driven during reset, sda=%b scl=%b", i2c_sda, i2c_scl);

    @(negedge clk) rst_n = 1'b1;

    wait (slave.stop_conditions == 1);
    wait (dut.clock_port.busy === 1'b0);
    repeat (400) @(posedge clk);

    if (dut.cpu.rf.x[20] !== 32'h0000_0045)
      $fatal(1, "first byte in x20 = %h, expected 45", dut.cpu.rf.x[20]);
    if (dut.cpu.rf.x[21] !== 32'h0000_0030)
      $fatal(1, "second byte in x21 = %h, expected 30", dut.cpu.rf.x[21]);

    if (slave.start_conditions !== 2)
      $fatal(1, "%0d START conditions, expected 2", slave.start_conditions);
    if (i2c_sda !== 1'b1 || i2c_scl !== 1'b1)
      $fatal(1, "bus not released, sda=%b scl=%b", i2c_sda, i2c_scl);

    $display("cpu_i2c_tb: PASS");
    $finish;
  end
endmodule
