`timescale 1ns / 1ps

// DHT11 controller reads one frame (55 %RH, 26 C) from the sensor model.
module dht11_mmio_tb;
  logic clk = 0, rst_n = 0, we = 0, re = 1;
  logic [31:0] a = 0, wd = 1;
  wire [31:0] rd;
  tri1 dht_io;
  always #5 clk = ~clk;

  dht11_mmio dut (.*);
  dht11_sensor_model sensor (.clk(clk), .data(dht_io));

  initial #30_000_000 $fatal(1, "timeout");

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;

    fork
      sensor.respond({8'd55, 8'd0, 8'd26, 8'd0, 8'd81});  // humidity, temperature, checksum
      begin
        @(negedge clk) we = 1;  // write START to 0x00
        @(negedge clk) we = 0;
        @(negedge clk);
        wait (rd[0] === 0);  // status bit 0 = busy
      end
    join

    if (rd[1] !== 1) $fatal(1, "status=%h, expected valid", rd);
    a = 4; #1;
    if (rd !== 32'h0000371a) $fatal(1, "measurement=%h, expected 0000371a", rd);

    $display("dht11_mmio_tb: PASS");
    $finish;
  end
endmodule
