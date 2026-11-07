`timescale 1ns/1ps

// Mode 0 framing at the bit level, plus the busy handshake the MMIO wrapper
// and the firmware both rely on. CLK_DIV is larger than the synthesis default
// so that a half period is long enough to measure.
module spi_master_tb;
  localparam integer CLK_DIV = 3;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic start = 1'b0;
  logic [7:0] tx_byte = 8'd0;
  wire busy;
  wire sck;
  wire mosi;

  logic [7:0] captured;
  integer index;
  integer sck_rises = 0;
  time last_rise;
  time high_width;

  spi_master #(.CLK_DIV(CLK_DIV)) dut (.*);

  always #5 clk = ~clk;

  always @(posedge sck) if (rst_n) sck_rises = sck_rises + 1;

  initial begin
    #20000;
    $fatal(1, "timeout, busy=%b sck=%b rises=%0d", busy, sck, sck_rises);
  end

  task automatic send_byte(input logic [7:0] value);
    begin
      @(negedge clk);
      tx_byte = value;
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;
    end
  endtask

  // A slave samples mosi on the rising edge, so the testbench does the same.
  task automatic capture_byte(output logic [7:0] value);
    begin
      for (index = 7; index >= 0; index = index - 1) begin
        @(posedge sck);
        value[index] = mosi;
      end
    end
  endtask

  initial begin
    // Reset holds the bus in the mode 0 idle state rather than leaving the
    // slave's clock input floating at an unknown level.
    repeat (2) @(negedge clk);
    #1;
    if (sck !== 1'b0) $fatal(1, "sck = %b during reset, mode 0 idles low", sck);
    if (busy !== 1'b0) $fatal(1, "busy set during reset");
    rst_n = 1'b1;
    @(negedge clk);

    // MSB first. 0xa5 alternates, so a reversed or stuck bit index shows up.
    fork
      capture_byte(captured);
      send_byte(8'ha5);
    join
    if (captured !== 8'ha5) $fatal(1, "captured %h, expected a5", captured);

    wait (busy === 1'b0);
    if (sck_rises !== 8) $fatal(1, "%0d sck rising edges for one byte, expected 8", sck_rises);
    if (sck !== 1'b0) $fatal(1, "sck = %b after the transfer, should return low", sck);

    // 0x01 puts the only set bit last, which catches a transfer that ends a
    // bit early.
    sck_rises = 0;
    fork
      capture_byte(captured);
      send_byte(8'h01);
    join
    if (captured !== 8'h01) $fatal(1, "captured %h, expected 01", captured);
    wait (busy === 1'b0);
    if (sck_rises !== 8) $fatal(1, "%0d sck rising edges for the second byte, expected 8", sck_rises);

    // The sck high time is what bounds the slave's setup and hold window, so
    // it has to come out at the parameterised half period.
    sck_rises = 0;
    send_byte(8'hf0);
    @(posedge sck);
    last_rise = $time;
    @(negedge sck);
    high_width = $time - last_rise;
    if (high_width !== CLK_DIV * 10)
      $fatal(1, "sck high for %0t, expected %0t", high_width, CLK_DIV * 10);
    wait (busy === 1'b0);

    // start asserted mid-transfer is ignored, not queued: the byte in flight
    // must not be corrupted by a second write.
    sck_rises = 0;
    fork
      capture_byte(captured);
      begin
        send_byte(8'h3c);
        repeat (CLK_DIV * 4) @(posedge clk);
        send_byte(8'hff);
      end
    join
    if (captured !== 8'h3c) $fatal(1, "captured %h, expected 3c, the mid-transfer start was not dropped", captured);
    wait (busy === 1'b0);
    repeat (CLK_DIV * 4) @(posedge clk);
    if (sck_rises !== 8)
      $fatal(1, "%0d sck rising edges, the mid-transfer start started a second byte", sck_rises);

    $display("spi_master_tb: PASS");
    $finish;
  end
endmodule
