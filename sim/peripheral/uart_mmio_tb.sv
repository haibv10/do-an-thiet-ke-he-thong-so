`timescale 1ns/1ps

module uart_mmio_tb;
  localparam integer CLKS_PER_BIT = 8;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic re = 1'b0;
  logic [31:0] a = 32'd0;
  logic [31:0] wd = 32'd0;
  logic rx = 1'b1;
  logic [31:0] rd;
  logic tx;
  integer bit_index;
  integer byte_index;

  always #5 clk = ~clk;

  uart_mmio #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) dut (.*);

  task automatic send_byte(input logic [7:0] value);
    @(negedge clk) rx = 1'b0;
    repeat (CLKS_PER_BIT) @(negedge clk);
    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
      rx = value[bit_index];
      repeat (CLKS_PER_BIT) @(negedge clk);
    end
    rx = 1'b1;
    repeat (CLKS_PER_BIT) @(negedge clk);
  endtask

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    send_byte(8'hc3);
    repeat (3) @(posedge clk);
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h0a) $fatal(1, "RX status=%h", rd);

    a = 32'h5000_0008;
    #1;
    if (rd !== 32'h0000_00c3) $fatal(1, "RX data=%h", rd);
    @(negedge clk) re = 1'b1;
    @(negedge clk) re = 1'b0;
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h00) $fatal(1, "RX status after pop=%h", rd);

    for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1)
      send_byte(8'h40 + byte_index);
    repeat (3) @(posedge clk);
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h82) $fatal(1, "RX full status=%h", rd);

    send_byte(8'hff);
    repeat (3) @(posedge clk);
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h86) $fatal(1, "RX overrun status=%h", rd);

    @(negedge clk) begin
      a = 32'h5000_000c;
      wd = 32'h0000_0004;
      we = 1'b1;
    end
    @(negedge clk) we = 1'b0;
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h86) $fatal(1, "status bit 2 cleared W1C=%h", rd);

    @(negedge clk) begin
      a = 32'h5000_000c;
      wd = 32'h0000_0001;
      we = 1'b1;
    end
    @(negedge clk) we = 1'b0;
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h82) $fatal(1, "RX W1C status=%h", rd);

    for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1) begin
      a = 32'h5000_0008;
      #1;
      if (rd !== (32'h0000_0040 + byte_index))
        $fatal(1, "RX FIFO data=%h index=%d", rd, byte_index);
      @(negedge clk) re = 1'b1;
      @(negedge clk) re = 1'b0;
    end
    a = 32'h5000_0004;
    #1;
    if (rd[7:0] !== 8'h00) $fatal(1, "RX FIFO did not empty=%h", rd);

    @(negedge clk) begin
      a = 32'h5000_0000;
      wd = 32'h0000_0055;
      we = 1'b1;
    end
    @(negedge clk) we = 1'b0;
    a = 32'h5000_0004;
    #1;
    if (!rd[0]) $fatal(1, "TX busy status");
    wait (!rd[0]);

    $display("uart_mmio_tb: PASS");
    $finish;
  end
endmodule
