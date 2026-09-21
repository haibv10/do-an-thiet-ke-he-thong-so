`timescale 1ns/1ps

// The register contract firmware codes against: one store launches one frame,
// busy gates the next, and a full turnaround read comes back through the data
// register.
module i2c_mmio_tb;
  localparam logic [6:0] SLAVE_ADDRESS = 7'h68;
  localparam logic [31:0] FRAME_REG  = 32'h0000_0000;
  localparam logic [31:0] STATUS_REG = 32'h0000_0004;
  localparam logic [31:0] DATA_REG   = 32'h0000_0008;

  localparam logic [31:0] START = 32'h0000_0100;
  localparam logic [31:0] STOP  = 32'h0000_0200;
  localparam logic [31:0] READ  = 32'h0000_0400;
  localparam logic [31:0] NACK  = 32'h0000_0800;

  localparam logic [31:0] ADDR_W = {SLAVE_ADDRESS, 1'b0};
  localparam logic [31:0] ADDR_R = {SLAVE_ADDRESS, 1'b1};

  localparam logic [31:0] BUSY = 32'h0000_0001;
  localparam logic [31:0] ACK  = 32'h0000_0002;

  logic clk = 1'b0;
  wire tick;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic [31:0] a = STATUS_REG;
  logic [31:0] wd = 32'd0;
  wire  [31:0] rd;
  tri1 sda;
  tri1 scl;

  logic [7:0] captured [0:6];
  int index;

  always #5 clk = ~clk;

  initial begin
    #4000000;
    $fatal(1, "I2C timeout, status=%h slave=%0d", rd, slave.state);
  end

  clock_enable #(.divider(4)) tick_divider (.clk, .rst_n, .tick);

  i2c_mmio dut (
    .clk, .tick, .rst_n, .we, .a, .wd, .rd, .sda, .scl
  );

  i2c_slave_model #(.ADDRESS(SLAVE_ADDRESS)) slave (.sda, .scl);

  task automatic bus_write(input logic [31:0] addr, input logic [31:0] value);
    begin
      @(negedge clk);
      a = addr;
      wd = value;
      we = 1'b1;
      @(negedge clk);
      we = 1'b0;
      a = STATUS_REG;
      #1;
    end
  endtask

  // Firmware polls busy before every store, so the testbench does the same.
  task automatic frame(input logic [31:0] value);
    begin
      wait (rd[0] === 1'b0);
      bus_write(FRAME_REG, value);
      @(negedge clk);
      #1;
      if ((rd & BUSY) === 32'd0) $fatal(1, "busy not set after launching a frame");
      wait (rd[0] === 1'b0);
    end
  endtask

  task automatic read_data(output logic [7:0] value);
    begin
      a = DATA_REG;
      #1;
      value = rd[7:0];
      a = STATUS_REG;
      #1;
    end
  endtask

  initial begin
    for (index = 0; index < 19; index++)
      slave.regs[index] = 8'h00;
    slave.regs[0] = 8'h45; slave.regs[1] = 8'h30; slave.regs[2] = 8'h13;
    slave.regs[3] = 8'h02; slave.regs[4] = 8'h21; slave.regs[5] = 8'h09;
    slave.regs[6] = 8'h26;

    repeat (4) @(negedge clk);
    #1;
    if ((rd & BUSY) !== 32'd0) $fatal(1, "busy set during reset");
    if (sda !== 1'b1 || scl !== 1'b1)
      $fatal(1, "bus driven during reset, sda=%b scl=%b", sda, scl);
    rst_n = 1'b1;
    repeat (4) @(negedge clk);

    // Point the slave at register 0, then turn the bus around.
    frame(START | ADDR_W);
    if ((rd & ACK) === 32'd0) $fatal(1, "slave did not acknowledge its address");
    frame(32'h0000_0000);
    if ((rd & ACK) === 32'd0) $fatal(1, "slave did not acknowledge the pointer");
    frame(START | ADDR_R);
    if ((rd & ACK) === 32'd0) $fatal(1, "slave did not acknowledge the read address");

    if (slave.start_conditions !== 2)
      $fatal(1, "%0d START conditions, expected 2", slave.start_conditions);

    for (index = 0; index < 6; index++) begin
      frame(READ);
      read_data(captured[index]);
    end
    frame(READ | NACK | STOP);
    read_data(captured[6]);

    for (index = 0; index < 7; index++)
      if (captured[index] !== slave.regs[index])
        $fatal(1, "byte %0d read back %h, expected %h",
               index, captured[index], slave.regs[index]);

    if (slave.stop_conditions !== 1)
      $fatal(1, "%0d STOP conditions, expected 1", slave.stop_conditions);
    if (sda !== 1'b1 || scl !== 1'b1)
      $fatal(1, "bus not released after the stop, sda=%b scl=%b", sda, scl);

    // A store arriving while a frame is in flight is dropped, not queued, so
    // the byte already on the wire is not disturbed.
    wait (rd[0] === 1'b0);
    bus_write(FRAME_REG, START | ADDR_W);
    repeat (40) @(posedge clk);
    bus_write(FRAME_REG, START | 32'h0000_0020);
    wait (rd[0] === 1'b0);
    if ((rd & ACK) === 32'd0)
      $fatal(1, "the frame in flight was replaced by the dropped store");
    if (slave.start_conditions !== 3)
      $fatal(1, "%0d START conditions, the dropped store emitted its own",
             slave.start_conditions);

    frame(32'h0000_000e);
    frame(32'h0000_001c | STOP);
    if (slave.regs[8'h0e] !== 8'h1c)
      $fatal(1, "register 0e holds %h, expected 1c", slave.regs[8'h0e]);

    // An address no slave holds must report no acknowledge, or a missing
    // device reads as a working one.
    frame(START | 32'h0000_0040 | STOP);
    if ((rd & ACK) !== 32'd0) $fatal(1, "an unheld address was acknowledged");

    // Every offset outside the map reads zero.
    a = FRAME_REG;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x00 read back %h", rd);
    a = 32'h0000_000c;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x0c read back %h", rd);

    $display("i2c_mmio_tb: PASS");
    $finish;
  end
endmodule
