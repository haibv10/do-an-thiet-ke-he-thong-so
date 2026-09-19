`timescale 1ns/1ps
module i2c_mmio_tb;
  logic clk=0, rst_n=0, we=0;
  wire tick;
  logic [31:0] a=0, wd=0, rd;
  tri1 sda;
  tri1 scl;
  logic slave_low=0, ack_clock_seen=0;
  integer ack_count=0;
  always #5 clk=~clk;
  clock_enable_divider #(.divider(27)) tick_divider (
    .clk, .rst_n, .tick
  );
  assign sda = slave_low ? 1'b0 : 1'bz;
  i2c_mmio dut (.*);
  always @(negedge dut.writer.sda_en) begin slave_low=1; ack_count=ack_count+1; end
  always @(posedge scl) if (slave_low && !dut.writer.sda_en) ack_clock_seen=1;
  always @(negedge scl) if (slave_low && ack_clock_seen) begin
    slave_low=0;
    ack_clock_seen=0;
  end
  initial begin
    #1000000;
    $fatal(1,"timeout busy=%b lcd_state=%0d i2c_state=%0d ack=%0d",
           dut.busy, dut.writer.state, dut.writer.i2c_writframe_inst.state, ack_count);
  end
  initial begin
    repeat(3) @(posedge clk); rst_n=1;
    @(negedge clk); a=32'h6000_0000; wd=32'h0000_0094; we=1;
    @(negedge clk); we=0; a=32'h6000_0004;
    wait(rd[0]===1); wait(rd[0]===0);
    @(negedge clk); a=32'h6000_0000; wd=32'h0000_0141; we=1;
    @(negedge clk); we=0; a=32'h6000_0004;
    wait(rd[0]===1); wait(rd[0]===0);
    if (dut.data !== 8'h41 || dut.cmd_data !== 1'b1)
      $fatal(1,"LCD data write was not retained");
    if (ack_count != 10) $fatal(1,"expected ten PCF8574 ACKs, got %0d",ack_count);
    $display("i2c_mmio_tb: PASS"); $finish;
  end
endmodule
