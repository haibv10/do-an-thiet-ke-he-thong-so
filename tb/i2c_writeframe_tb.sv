`timescale 1ns/1ps

module i2c_writeframe_tb;
  logic clk_1MHz = 1'b0;
  logic rst_n = 1'b0;
  logic en_write = 1'b0;
  logic start_frame = 1'b0;
  logic stop_frame = 1'b0;
  logic [7:0] data = 8'h00;
  tri1 sda;
  logic slave_drive_low = 1'b0;
  logic scl;
  logic done;
  logic sda_en;
  logic [7:0] received_data = 8'h00;
  logic frame_active = 1'b0;
  integer received_bits = 0;
  integer start_count = 0;
  integer stop_count = 0;
  integer ack_count = 0;

  always #5 clk_1MHz = ~clk_1MHz;

  assign sda = slave_drive_low ? 1'b0 : 1'bz;

  i2c_writeframe dut (
    .clk_1MHz,
    .rst_n,
    .en_write,
    .start_frame,
    .stop_frame,
    .data,
    .sda,
    .scl,
    .done,
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
    slave_drive_low = 1'b1;
    ack_count = ack_count + 1;
  end

  // Release SDA after the ACK clock pulse so the pull-up restores logic 1.
  always @(negedge scl)
    if (slave_drive_low)
      slave_drive_low = 1'b0;

  initial begin
    repeat (3) @(posedge clk_1MHz);
    rst_n = 1'b1;

    @(negedge clk_1MHz);
    data = 8'hA5;
    start_frame = 1'b1;
    stop_frame = 1'b1;
    en_write = 1'b1;
    @(negedge clk_1MHz);
    en_write = 1'b0;

    wait (done === 1'b1);
    @(posedge clk_1MHz);

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

    $display("i2c_writeframe_tb: PASS");
    $finish;
  end
endmodule
