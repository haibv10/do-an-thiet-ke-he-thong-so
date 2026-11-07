`timescale 1ns/1ps

module uart_tx_tb;
  localparam integer CLKS_PER_BIT = 8;
  localparam logic [31:0] DATA_REG   = 32'h0000_0000;
  localparam logic [31:0] STATUS_REG = 32'h0000_0004;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic we = 1'b0;
  logic [31:0] a = STATUS_REG;
  logic [31:0] wd = 32'd0;
  wire  [31:0] rd;
  wire         tx;

  logic [7:0] captured;
  integer index;
  integer accepted_writes = 0;

  uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (.*);

  always @(posedge dut.busy) if (rst_n) accepted_writes = accepted_writes + 1;

  always #5 clk = ~clk;

  initial begin
    #40000;
    $fatal(1, "timeout, tx=%b busy=%b accepted=%0d", tx, rd[0], accepted_writes);
  end

  task automatic send_byte(input logic [7:0] value);
    begin
      @(negedge clk);
      a = DATA_REG;
      wd = {24'd0, value};
      we = 1'b1;
      @(negedge clk);
      we = 1'b0;
      a = STATUS_REG;
    end
  endtask

  task automatic capture_frame(output logic [7:0] value);
    begin
      @(negedge tx);
      repeat (CLKS_PER_BIT / 2) @(posedge clk);
      if (tx !== 1'b0) $fatal(1, "start bit was not low");
      for (index = 0; index < 8; index = index + 1) begin
        repeat (CLKS_PER_BIT) @(posedge clk);
        value[index] = tx;
      end
      repeat (CLKS_PER_BIT) @(posedge clk);
      if (tx !== 1'b1) $fatal(1, "stop bit was not high");
    end
  endtask

  initial begin

    repeat (2) @(negedge clk);
    #1;
    if (tx !== 1'b1) $fatal(1, "tx = %b during reset, should idle high", tx);
    rst_n = 1'b1;
    @(negedge clk);
    #1;
    if (rd[0] !== 1'b0) $fatal(1, "busy set before any write");

    fork
      capture_frame(captured);
      send_byte(8'h41);
    join
    if (captured !== 8'h41) $fatal(1, "captured %h, expected 41", captured);

    wait (rd[0] === 1'b0);
    fork
      capture_frame(captured);
      send_byte(8'ha5);
    join
    if (captured !== 8'ha5) $fatal(1, "captured %h, expected a5", captured);

    wait (rd[0] === 1'b0);
    accepted_writes = 0;
    send_byte(8'h5a);
    @(negedge clk);
    #1;
    if (rd[0] !== 1'b1) $fatal(1, "busy not set after a write");

    repeat (CLKS_PER_BIT * 3) @(posedge clk);
    send_byte(8'hff);
    wait (rd[0] === 1'b0);
    repeat (CLKS_PER_BIT * 12) @(posedge clk);
    if (accepted_writes !== 1)
      $fatal(1, "%0d writes accepted, the one arriving mid-frame was not dropped",
             accepted_writes);

    a = DATA_REG;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x00 read back %h", rd);
    a = 32'h0000_0008;
    #1;
    if (rd !== 32'd0) $fatal(1, "offset 0x08 read back %h", rd);
    a = STATUS_REG;

    $display("uart_tx_tb: PASS");
    $finish;
  end
endmodule
