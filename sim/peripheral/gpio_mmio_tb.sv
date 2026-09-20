`timescale 1ns/1ps

module gpio_mmio_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic [31:0] a = 32'd0;
  logic [31:0] wd = 32'd0;
  wire  [31:0] rd;
  wire  led;

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

    a = 32'h0000_0000;
    #1;
    if (rd[0] !== 1'b0 || led !== 1'b0) $fatal(1, "LED not clear after reset");

    // Write and read back the LED register.
    write_reg(32'h0000_0000, 32'd1);
    a = 32'h0000_0000;
    #1;
    if (led !== 1'b1 || rd[0] !== 1'b1) $fatal(1, "LED did not set");

    write_reg(32'h0000_0000, 32'd0);
    #1;
    if (led !== 1'b0) $fatal(1, "LED did not clear");

    // The removed input register now reads as an unmapped offset.
    a = 32'h0000_0004;
    #1;
    if (rd !== 32'd0) $fatal(1, "removed button offset = %h", rd);

    // Any other offset reads as zero.
    a = 32'h0000_0008;
    #1;
    if (rd !== 32'd0) $fatal(1, "unmapped offset = %h", rd);

    $display("gpio_mmio_tb: PASS");
    $finish;
  end
endmodule
