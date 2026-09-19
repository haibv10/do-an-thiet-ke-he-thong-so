`timescale 1ns/1ps

module i2c_writeframe_tb;
  logic clk = 1'b0;
  wire tick;
  logic rst_n = 1'b0;
  logic en_write = 1'b0;
  logic start_frame = 1'b0;
  logic stop_frame = 1'b0;
  logic [7:0] data = 8'h00;
  tri1 sda;
  logic slave_drive_low = 1'b0;
  logic provide_ack = 1'b1;
  logic ack_clock_seen = 1'b0;
  tri1 scl;
  logic done;
  logic ack;
  logic sda_en;
  logic [7:0] received_data = 8'h00;
  logic frame_active = 1'b0;
  integer received_bits = 0;
  integer start_count = 0;
  integer stop_count = 0;
  integer ack_count = 0;

  always #5 clk = ~clk;

  initial begin
    #100000;
    $fatal(1, "I2C timeout state=%0d count=%0d tick=%b ack=%b",
           dut.state, dut.cnt, tick, ack);
  end

  clock_enable_divider #(.divider(4)) tick_divider (
    .clk, .rst_n, .tick
  );

  assign sda = slave_drive_low ? 1'b0 : 1'bz;

  i2c_writeframe dut (
    .clk,
    .tick,
    .rst_n,
    .en_write,
    .start_frame,
    .stop_frame,
    .data,
    .sda,
    .scl,
    .done,
    .ack,
    .sda_en
  );

  always @(negedge sda)
    if (scl === 1'b1) begin
      start_count = start_count + 1;
      frame_active = 1'b1;
    end

  always @(posedge sda)
    if (scl === 1'b1) begin
      stop_count = stop_count + 1;
      frame_active = 1'b0;
    end

  always @(posedge scl) begin
    if (frame_active && sda_en && received_bits < 8) begin
      received_data = {received_data[6:0], sda};
      received_bits = received_bits + 1;
    end
  end

  // Acknowledge after the controller releases SDA for the ACK bit.
  always @(negedge sda_en) begin
    if (provide_ack) begin
      slave_drive_low = 1'b1;
      ack_count = ack_count + 1;
    end
  end

  // Release SDA after the ACK clock pulse so the pull-up restores logic 1.
  always @(posedge scl)
    if (slave_drive_low && !sda_en)
      ack_clock_seen = 1'b1;

  always @(negedge scl)
    if (slave_drive_low && ack_clock_seen) begin
      slave_drive_low = 1'b0;
      ack_clock_seen = 1'b0;
    end

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    data = 8'hA5;
    start_frame = 1'b1;
    stop_frame = 1'b1;
    en_write = 1'b1;
    repeat (4) @(negedge clk);
    en_write = 1'b0;

    wait (done === 1'b1);
    @(posedge clk);

    if (received_bits != 8)
      $fatal(1, "expected 8 data bits, got %0d", received_bits);
    if (received_data !== 8'hA5)
      $fatal(1, "expected data A5, got %h", received_data);
    if (start_count != 1)
      $fatal(1, "expected one START, got %0d", start_count);
    if (stop_count != 1)
      $fatal(1, "expected one STOP, got %0d", stop_count);
    if (ack_count != 1)
      $fatal(1, "expected one ACK cycle, got %0d", ack_count);
    if (ack !== 1'b1)
      $fatal(1, "expected ACK result");

    wait (done === 1'b0);
    @(negedge clk);
    provide_ack = 1'b0;
    data = 8'h5A;
    start_frame = 1'b1;
    stop_frame = 1'b1;
    en_write = 1'b1;
    repeat (4) @(negedge clk);
    en_write = 1'b0;
    wait (done === 1'b1);
    @(posedge clk);

    if (ack !== 1'b0)
      $fatal(1, "expected NACK result");
    if (ack_count != 1)
      $fatal(1, "unexpected ACK during NACK transfer");

    $display("i2c_writeframe_tb: PASS");
    $finish;
  end
endmodule
