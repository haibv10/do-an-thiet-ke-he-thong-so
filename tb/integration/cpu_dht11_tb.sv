`timescale 1ns / 1ps
module cpu_dht11_tb;
  logic clk = 0, rst_n = 0;
  tri1 dht11_data;
  integer index;
  always #5 clk = ~clk;
  soc_top dut (.clk(clk), .rst_n(rst_n), .uart_rx_in(1'b1), .dht11_data(dht11_data));
  dht11_sensor_model sensor (.clk(clk), .data(dht11_data));
  initial begin
    #10000000;
    $fatal(1, "CPU DHT11 timeout");
  end
  initial begin
    #1;
    for (index = 0; index < 2048; index++) dut.rom.rom[index] = 32'h00000013;
    dut.rom.rom[0] = 32'h800000b7; // lui x1,0x80000
    dut.rom.rom[1] = 32'h00100113; // addi x2,x0,1
    dut.rom.rom[2] = 32'h0020a023; // sw x2,0(x1): start
    dut.rom.rom[3] = 32'h0000a183; // lw x3,0(x1): status
    dut.rom.rom[4] = 32'h0011f193; // andi x3,x3,1
    dut.rom.rom[5] = 32'hfe019ce3; // bne x3,x0,-8
    dut.rom.rom[6] = 32'h0000a203; // lw x4,0(x1)
    dut.rom.rom[7] = 32'h0040a283; // lw x5,4(x1)
    dut.rom.rom[8] = 32'h0000006f;
    repeat (3) @(negedge clk);
    rst_n = 1;
    sensor.respond({8'd55, 8'd0, 8'd26, 8'd0, 8'd81});
    repeat (30) @(negedge clk);
    if (dut.cpu.rf.x[4] !== 2 || dut.cpu.rf.x[5] !== 32'h371a)
      $fatal(1, "CPU DHT11 status=%h data=%h", dut.cpu.rf.x[4], dut.cpu.rf.x[5]);
    $display("cpu_dht11_tb: PASS");
    $finish;
  end
endmodule
