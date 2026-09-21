`timescale 1ns/1ps

module i2c_master_tb;
  localparam logic [6:0] SLAVE_ADDRESS = 7'h68;
  localparam logic [7:0] WRITE_BYTE = {SLAVE_ADDRESS, 1'b0};
  localparam logic [7:0] READ_BYTE  = {SLAVE_ADDRESS, 1'b1};

  logic clk = 1'b0;
  wire tick;
  logic rst_n = 1'b0;
  logic en = 1'b0;
  logic rw = 1'b0;
  logic start_frame = 1'b0;
  logic stop_frame = 1'b0;
  logic ack_out = 1'b0;
  logic [7:0] data = 8'h00;
  tri1 sda;
  tri1 scl;
  wire done;
  wire busy;
  wire [7:0] data_out;
  wire ack;
  wire sda_en;

  logic [7:0] captured [0:6];
  int index;

  always #5 clk = ~clk;

  initial begin
    #4000000;
    $fatal(1, "I2C timeout master=%0d slave=%0d", dut.state, slave.state);
  end

  clock_enable #(.divider(4)) tick_divider (.clk, .rst_n, .tick);

  i2c_master dut (
    .clk, .tick, .rst_n, .en, .rw, .start_frame, .stop_frame, .ack_out,
    .data, .sda, .scl, .done, .busy, .data_out, .ack, .sda_en
  );

  i2c_slave_model #(.ADDRESS(SLAVE_ADDRESS)) slave (.sda, .scl);

  // One frame, held until the master reports it finished.
  task automatic frame(input logic do_start, input logic is_read,
                       input logic [7:0] value, input logic refuse,
                       input logic do_stop);
    begin
      @(negedge clk);
      start_frame = do_start;
      stop_frame  = do_stop;
      rw          = is_read;
      ack_out     = refuse;
      data        = value;
      en          = 1'b1;
      @(posedge done);
      @(negedge clk);
      en = 1'b0;
      start_frame = 1'b0;
      stop_frame = 1'b0;
      @(negedge clk);
    end
  endtask

  initial begin
    for (index = 0; index < 19; index++)
      slave.regs[index] = 8'h00;
    slave.regs[0] = 8'h45; slave.regs[1] = 8'h30; slave.regs[2] = 8'h13;
    slave.regs[3] = 8'h02; slave.regs[4] = 8'h21; slave.regs[5] = 8'h09;
    slave.regs[6] = 8'h26;

    repeat (4) @(negedge clk);
    rst_n = 1'b1;
    repeat (4) @(negedge clk);

    // A write frame behaves as it did before the read path existed.
    frame(1'b1, 1'b0, WRITE_BYTE, 1'b0, 1'b0);
    if (ack !== 1'b1) $fatal(1, "slave did not acknowledge its own address");

    // Set the pointer, then turn the bus around with a repeated START rather
    // than a STOP: a register read has no other way in.
    frame(1'b0, 1'b0, 8'h00, 1'b0, 1'b0);
    if (ack !== 1'b1) $fatal(1, "slave did not acknowledge the register pointer");

    frame(1'b1, 1'b0, READ_BYTE, 1'b0, 1'b0);
    if (ack !== 1'b1) $fatal(1, "slave did not acknowledge the read address after a repeated START");

    if (slave.start_conditions !== 2)
      $fatal(1, "%0d START conditions, expected 2", slave.start_conditions);
    if (slave.stop_conditions !== 0)
      $fatal(1, "%0d STOP conditions before the read finished", slave.stop_conditions);

    // Six acknowledged bytes and a seventh refused, which is what ends a read.
    for (index = 0; index < 6; index++) begin
      frame(1'b0, 1'b1, 8'h00, 1'b0, 1'b0);
      captured[index] = data_out;
    end
    frame(1'b0, 1'b1, 8'h00, 1'b1, 1'b1);
    captured[6] = data_out;

    for (index = 0; index < 7; index++)
      if (captured[index] !== slave.regs[index])
        $fatal(1, "byte %0d read back %h, expected %h",
               index, captured[index], slave.regs[index]);

    if (slave.stop_conditions !== 1)
      $fatal(1, "%0d STOP conditions, expected 1", slave.stop_conditions);

    // The refusal has to reach the slave, or it keeps driving the bus into the
    // next transaction.
    if (slave.state !== slave.IDLE)
      $fatal(1, "slave state %0d after the stop, expected IDLE", slave.state);

    // The bus is free again: neither side is pulling a line down.
    if (sda !== 1'b1 || scl !== 1'b1)
      $fatal(1, "bus not released after the stop, sda=%b scl=%b", sda, scl);

    // A byte written to one register and read back through a second
    // transaction proves the pointer and both directions agree.
    frame(1'b1, 1'b0, WRITE_BYTE, 1'b0, 1'b0);
    frame(1'b0, 1'b0, 8'h0e, 1'b0, 1'b0);
    frame(1'b0, 1'b0, 8'h1c, 1'b0, 1'b1);
    if (slave.regs[8'h0e] !== 8'h1c)
      $fatal(1, "register 0e holds %h, expected 1c", slave.regs[8'h0e]);

    frame(1'b1, 1'b0, WRITE_BYTE, 1'b0, 1'b0);
    frame(1'b0, 1'b0, 8'h0e, 1'b0, 1'b0);
    frame(1'b1, 1'b0, READ_BYTE, 1'b0, 1'b0);
    frame(1'b0, 1'b1, 8'h00, 1'b1, 1'b1);
    if (data_out !== 8'h1c)
      $fatal(1, "read back %h from register 0e, expected 1c", data_out);

    // An address belonging to nobody must come back unacknowledged, or a
    // missing device looks like a working one.
    frame(1'b1, 1'b0, 8'h20, 1'b0, 1'b1);
    if (ack !== 1'b0) $fatal(1, "an address no slave holds was acknowledged");

    $display("i2c_master_tb: PASS");
    $finish;
  end
endmodule
