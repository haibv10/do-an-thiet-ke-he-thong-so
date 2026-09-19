`timescale 1ns/1ps

module gpio_mmio_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic [31:0] a = 32'd0;
  logic [31:0] wd = 32'd0;
  wire  [31:0] rd;
  wire  led;
  logic btn_in = 1'b1;

  gpio_mmio dut (.*);

  always #5 clk = ~clk;

  task automatic write_reg(input logic [31:0] offset, input logic [31:0] value);
    begin
      @(negedge clk);
      a = offset;
      wd = value;
      we = 1'b1;
      @(negedge clk);
      we = 1'b0;
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    // Reset leaves the LED off and the button reading released, since it is
    // active low with a pull-up.
    a = 32'h0000_0000;
    #1;
    if (rd[0] !== 1'b0 || led !== 1'b0) $fatal(1, "LED not clear after reset");
    a = 32'h0000_0004;
    #1;
    if (rd[0] !== 1'b1) $fatal(1, "button reads pressed after reset");

    // Write and read back the LED register.
    write_reg(32'h0000_0000, 32'd1);
    a = 32'h0000_0000;
    #1;
    if (led !== 1'b1 || rd[0] !== 1'b1) $fatal(1, "LED did not set");

    write_reg(32'h0000_0000, 32'd0);
    #1;
    if (led !== 1'b0) $fatal(1, "LED did not clear");

    // The button offset is read only; a write there must not disturb the LED.
    write_reg(32'h0000_0000, 32'd1);
    write_reg(32'h0000_0004, 32'd0);
    a = 32'h0000_0000;
    #1;
    if (led !== 1'b1) $fatal(1, "a write to the button offset changed the LED");

    // The button passes through two synchroniser stages, so a change on the pin
    // becomes visible to software two clock edges later and never sooner.
    a = 32'h0000_0004;
    @(negedge clk);
    btn_in = 1'b0;
    @(posedge clk);
    #1;
    if (rd[0] !== 1'b1) $fatal(1, "button visible after one edge, not synchronised");
    @(posedge clk);
    #1;
    if (rd[0] !== 1'b0) $fatal(1, "button not visible after two edges");

    @(negedge clk);
    btn_in = 1'b1;
    repeat (2) @(posedge clk);
    #1;
    if (rd[0] !== 1'b1) $fatal(1, "button release not seen");

    // Any other offset reads as zero.
    a = 32'h0000_0008;
    #1;
    if (rd !== 32'd0) $fatal(1, "unmapped offset = %h", rd);

    $display("gpio_mmio_tb: PASS");
    $finish;
  end
endmodule
