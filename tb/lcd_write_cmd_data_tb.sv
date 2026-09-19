`timescale 1ns/1ps

module lcd_write_cmd_data_tb;
  logic clk = 1'b0;
  wire tick;
  logic rst_n = 1'b0;
  logic [7:0] data = 8'h41;
  logic cmd_data = 1'b1;
  logic ena = 1'b0;
  logic [6:0] i2c_addr = 7'h27;
  tri1 sda;
  logic slave_drive_low = 1'b0;
  logic ack_clock_seen = 1'b0;
  tri1 scl;
  logic done;
  logic ack;
  logic sda_en;
  logic [7:0] received_bytes [0:4];
  logic [7:0] current_byte = 8'h00;
  logic frame_active = 1'b0;
  integer bit_count = 0;
  integer byte_count = 0;
  integer start_count = 0;
  integer stop_count = 0;
  integer ack_count = 0;
  integer index;

  always #5 clk = ~clk;

  initial begin
    #100000;
    $fatal(1, "LCD timeout state=%0d count=%0d I2C state=%0d",
           dut.state, dut.cnt, dut.i2c_writframe_inst.state);
  end

  clock_enable_divider #(.divider(4)) tick_divider (
    .clk, .rst_n, .tick
  );

  assign sda = slave_drive_low ? 1'b0 : 1'bz;

  lcd_write_cmd_data dut (.*);

  // START: SDA falls while SCL is high. STOP: SDA rises while SCL is high, and
  // only inside a frame - a transition before the START is not a STOP. All five
  // PCF8574 frames sit between one START and one STOP.
  always @(negedge sda)
    if (scl === 1'b1) begin
      start_count = start_count + 1;
      frame_active = 1'b1;
    end

  always @(posedge sda)
    if (scl === 1'b1 && frame_active) begin
      stop_count = stop_count + 1;
      frame_active = 1'b0;
    end

  always @(posedge scl) begin
    if (frame_active && sda_en && byte_count < 5) begin
      current_byte = {current_byte[6:0], sda};
      bit_count = bit_count + 1;
      if (bit_count == 8) begin
        received_bytes[byte_count] = current_byte;
        byte_count = byte_count + 1;
        bit_count = 0;
        current_byte = 8'h00;
      end
    end
  end

  always @(negedge sda_en) begin
    slave_drive_low = 1'b1;
    ack_count = ack_count + 1;
  end

  always @(posedge scl)
    if (slave_drive_low && !sda_en)
      ack_clock_seen = 1'b1;

  always @(negedge scl)
    if (slave_drive_low && ack_clock_seen) begin
      slave_drive_low = 1'b0;
      ack_clock_seen = 1'b0;
    end

  initial begin
    for (index = 0; index < 5; index = index + 1)
      received_bytes[index] = 8'h00;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);
    ena = 1'b1;
    repeat (4) @(negedge clk);
    ena = 1'b0;

    wait (done === 1'b1);
    @(posedge clk);

    if (byte_count != 5)
      $fatal(1, "expected 5 I2C bytes, got %0d", byte_count);
    if (received_bytes[0] !== 8'h4E || received_bytes[1] !== 8'h4D ||
        received_bytes[2] !== 8'h49 || received_bytes[3] !== 8'h1D ||
        received_bytes[4] !== 8'h19)
      $fatal(1, "unexpected PCF8574 sequence: %h %h %h %h %h",
             received_bytes[0], received_bytes[1], received_bytes[2],
             received_bytes[3], received_bytes[4]);
    if (start_count != 1 || stop_count != 1)
      $fatal(1, "expected one START and one STOP, got %0d and %0d",
             start_count, stop_count);
    if (ack_count != 5)
      $fatal(1, "expected 5 ACK cycles, got %0d", ack_count);
    if (ack !== 1'b1)
      $fatal(1, "expected final PCF8574 ACK");
    if (scl !== 1'b1 || sda !== 1'b1)
      $fatal(1, "bus not idle after STOP, scl=%b sda=%b", scl, sda);

    $display("lcd_write_cmd_data_tb: PASS");
    $finish;
  end
endmodule
