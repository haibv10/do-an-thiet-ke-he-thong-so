`timescale 1ns / 1ps

// SPI mode 0 at the SoC divider (CLK_DIV = 1): send one byte, sample MOSI on SCK rising edges.
module spi_master_tb;
  logic clk = 0, rst_n = 0, start = 0;
  logic [7:0] tx_byte = 0, received;
  wire busy, sck, mosi;
  always #5 clk = ~clk;

  spi_master #(.CLK_DIV(1)) dut (.*);

  initial #10_000 $fatal(1, "timeout");

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;

    @(negedge clk) {tx_byte, start} = {8'h35, 1'b1};
    @(negedge clk) start = 0;
    for (int b = 7; b >= 0; b--) begin
      @(posedge sck);
      received[b] = mosi;
    end
    wait (!busy);

    if (received !== 8'h35) $fatal(1, "MOSI sent %h, expected 35", received);
    if (sck !== 0) $fatal(1, "SCK not idle low after the byte");

    $display("spi_master_tb: PASS");
    $finish;
  end
endmodule
