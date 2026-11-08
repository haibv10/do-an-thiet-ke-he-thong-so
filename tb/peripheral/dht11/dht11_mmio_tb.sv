`timescale 1ns / 1ps
module dht11_mmio_tb;
  logic clk = 0, rst_n = 0, we = 0, re = 1;
  logic [31:0] a = 0, wd = 1;
  wire [31:0] rd;
  tri1 dht_io;
  always #5 clk = ~clk;
  dht11_mmio dut (.*);
  dht11_sensor_model sensor (.clk(clk), .data(dht_io));

  task automatic start;
    @(negedge clk); a = 0; we = 1;
    @(negedge clk); we = 0;
  endtask

  task automatic result(input logic [2:0] status);
    wait (!dut.busy);
    @(negedge clk); a = 0;
    #1;
    if (rd !== {29'd0, status}) $fatal(1, "status=%h expected %h", rd, status);
  endtask

  initial begin
    #30000000;
    $fatal(1, "DHT11 test timeout");
  end
  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;
    fork
      sensor.respond({8'd55, 8'd0, 8'd26, 8'd0, 8'd81});
      begin
        start();
        repeat (100) @(negedge clk);
        start(); // A command while busy must not restart acquisition.
        repeat (10) @(negedge clk);
        if (dut.timer < 100) $fatal(1, "busy START reset timer");
        result(3'b010);
      end
    join
    a = 4; #1;
    if (rd !== 32'h0000371a) $fatal(1, "measurement=%h", rd);
    re = 0; #1;
    if (rd !== 0) $fatal(1, "read without enable");
    re = 1;
    fork
      sensor.respond({8'd55, 8'd0, 8'd26, 8'd0, 8'd80});
      begin start(); result(3'b100); end
    join
    // No sensor response: controller must time out and release the bus.
    start(); result(3'b100);
    if (dht_io !== 1'b1) $fatal(1, "bus not released after timeout");
    // Recovery after checksum and timeout failures.
    fork
      sensor.respond({8'd40, 8'd0, 8'd25, 8'd0, 8'd65});
      begin start(); result(3'b010); end
    join
    a = 4; #1;
    if (rd !== 32'h00002819) $fatal(1, "recovery measurement=%h", rd);
    $display("dht11_mmio_tb: PASS");
    $finish;
  end
endmodule
