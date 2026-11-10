`timescale 1ns / 1ps

// I2C master writes 0x3A to register 0x01 of a slave model, then reads it back.
module i2c_master_tb;
  localparam [6:0] SLAVE = 7'h68;

  logic clk = 0, rst_n = 0, en = 0, rw = 0, start_frame = 0, stop_frame = 0, ack_out = 0;
  logic [7:0] data = 0;
  tri1 sda, scl;
  wire tick, done, busy, ack, sda_en;
  wire [7:0] data_out;
  always #5 clk = ~clk;

  clock_enable #(.divider(4)) tick_gen (.clk, .rst_n, .tick);
  i2c_master dut (.*);
  i2c_register_slave_model #(.ADDRESS(SLAVE)) slave (.sda, .scl);

  // One byte on the bus. nack = 1 marks the last byte of a read.
  task automatic frame(input start, stop, read, nack, input [7:0] value);
    @(negedge clk);
    {start_frame, stop_frame, rw, ack_out, data} = {start, stop, read, nack, value};
    en = 1;
    @(posedge done);
    @(negedge clk) en = 0;
    @(negedge clk);
  endtask

  initial #5_000_000 $fatal(1, "timeout");

  initial begin
    repeat (4) @(negedge clk);
    rst_n = 1;

    // Write: START, address+W, register 0x01, data 0x3A, STOP
    frame(1, 0, 0, 0, {SLAVE, 1'b0});
    if (ack !== 1) $fatal(1, "address not acknowledged");
    frame(0, 0, 0, 0, 8'h01);
    frame(0, 1, 0, 0, 8'h3a);
    if (slave.regs[1] !== 8'h3a) $fatal(1, "slave register=%h, expected 3a", slave.regs[1]);

    // Read: START, address+W, register 0x01, repeated START, address+R, read with NACK, STOP
    frame(1, 0, 0, 0, {SLAVE, 1'b0});
    frame(0, 0, 0, 0, 8'h01);
    frame(1, 0, 0, 0, {SLAVE, 1'b1});
    frame(0, 1, 1, 1, 8'h00);
    if (data_out !== 8'h3a) $fatal(1, "read back %h, expected 3a", data_out);

    $display("i2c_master_tb: PASS");
    $finish;
  end
endmodule
