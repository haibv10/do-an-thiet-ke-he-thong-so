`timescale 1ns / 1ps

module spi_mmio_tb;
  localparam integer CLK_DIV = 3;
  localparam logic [31:0] DATA_REG = 32'h0000_0000;
  localparam logic [31:0] STATUS_REG = 32'h0000_0004;
  localparam logic [31:0] CTRL_REG = 32'h0000_0008;

  logic          clk = 1'b0;
  logic          rst_n = 1'b0;
  logic          we = 1'b0;
  logic   [31:0] a = STATUS_REG;
  logic   [31:0] wd = 32'd0;
  wire    [31:0] rd;
  wire           spi_sck;
  wire           spi_mosi;
  wire           spi_cs_n;
  wire           spi_dc;
  wire           spi_rst_n;

  logic   [ 7:0] captured;
  integer        index;
  integer        sck_rises = 0;

  spi_mmio #(.CLK_DIV(CLK_DIV)) dut (.*);

  always #5 clk = ~clk;

  always @(posedge spi_sck) if (rst_n) sck_rises = sck_rises + 1;

  initial begin
    #20000;
    $fatal(1, "timeout, busy=%b rises=%0d", rd[0], sck_rises);
  end

  task automatic bus_write(input logic [31:0] addr, input logic [31:0] value);
    begin
      @(negedge clk);
      a  = addr;
      wd = value;
      we = 1'b1;
      @(negedge clk);
      we = 1'b0;
      a  = STATUS_REG;
      #1;
    end
  endtask

  task automatic capture_byte(output logic [7:0] value);
    begin
      for (index = 7; index >= 0; index = index - 1) begin
        @(posedge spi_sck);
        value[index] = spi_mosi;
      end
    end
  endtask

  initial begin

    repeat (2) @(negedge clk);
    #1;
    if (spi_cs_n !== 1'b1) $fatal(1, "cs_n = %b during reset, should be deselected", spi_cs_n);
    if (spi_rst_n !== 1'b0)
      $fatal(1, "panel rst_n = %b during reset, should be asserted", spi_rst_n);
    if (spi_sck !== 1'b0) $fatal(1, "sck = %b during reset", spi_sck);
    rst_n = 1'b1;
    @(negedge clk);
    #1;
    if (rd[0] !== 1'b0) $fatal(1, "busy set before any write");

    bus_write(CTRL_REG, 32'h0000_0006);
    a = CTRL_REG;
    #1;
    if (spi_cs_n !== 1'b0) $fatal(1, "cs_n = %b after control write", spi_cs_n);
    if (spi_dc !== 1'b1) $fatal(1, "dc = %b after control write", spi_dc);
    if (spi_rst_n !== 1'b1) $fatal(1, "panel rst_n = %b after control write", spi_rst_n);
    if (rd[2:0] !== 3'b110) $fatal(1, "control read back %b", rd[2:0]);
    a         = STATUS_REG;

    sck_rises = 0;
    fork
      capture_byte(captured);
      bus_write(DATA_REG, 32'h0000_005a);
    join
    if (captured !== 8'h5a) $fatal(1, "captured %h, expected 5a", captured);
    wait (rd[0] === 1'b0);
    if (sck_rises !== 8) $fatal(1, "%0d sck rising edges, expected 8", sck_rises);

    sck_rises = 0;
    fork
      capture_byte(captured);
      bus_write(DATA_REG, 32'hdead_be3c);
    join
    if (captured !== 8'h3c) $fatal(1, "captured %h, expected 3c", captured);
    wait (rd[0] === 1'b0);

    sck_rises = 0;
    bus_write(DATA_REG, 32'h0000_00ff);
    @(negedge clk);
    #1;
    if (rd[0] !== 1'b1) $fatal(1, "busy not set after a data write");
    repeat (CLK_DIV * 4) @(posedge clk);
    bus_write(DATA_REG, 32'h0000_0000);
    wait (rd[0] === 1'b0);
    repeat (CLK_DIV * 4) @(posedge clk);
    if (sck_rises !== 8)
      $fatal(1, "%0d sck rising edges, the write during busy was not dropped", sck_rises);

    bus_write(DATA_REG, 32'h0000_00aa);
    bus_write(CTRL_REG, 32'h0000_0005);
    #1;
    if (spi_cs_n !== 1'b1) $fatal(1, "cs_n = %b after control write during a transfer", spi_cs_n);
    if (spi_dc !== 1'b0) $fatal(1, "dc = %b after control write during a transfer", spi_dc);
    wait (rd[0] === 1'b0);

    a = DATA_REG;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x00 read back %h", rd);
    a = 32'h0000_000c;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x0c read back %h", rd);
    a = STATUS_REG;

    $display("spi_mmio_tb: PASS");
    $finish;
  end
endmodule
