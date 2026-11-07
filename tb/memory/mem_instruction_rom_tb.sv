`timescale 1ns / 1ps

module mem_instruction_rom_tb;
  logic        clk = 1'b0;
  logic [31:0] a = 32'd0;
  wire  [31:0] rd;
  logic [31:0] a_data = 32'd0;
  wire  [31:0] rd_data;

  mem_instruction_rom #(.HEX_PATH("tb/support/imem_test.hex")) dut (.*);

  always #5 clk = ~clk;

  task automatic fetch(input logic [31:0] addr, input logic [31:0] value, input string label);
    begin
      @(posedge clk);
      a = addr;
      @(posedge clk);
      #1;
      if (rd !== value) $fatal(1, "%s: fetch [%h] = %h, expected %h", label, addr, rd, value);
    end
  endtask

  initial begin

    fetch(32'h0000_0000, 32'hdead_beef, "word 0");
    fetch(32'h0000_0004, 32'hcafe_babe, "word 1");
    fetch(32'h0000_0008, 32'h1234_5678, "word 2");
    fetch(32'h0000_000c, 32'h9abc_def0, "word 3");

    fetch(32'h0000_0010, 32'h0000_0000, "past the end of the image");
    fetch(32'h0000_1ffc, 32'h0000_0000, "last word of the ROM");

    fetch(32'h0000_0002, 32'hdead_beef, "byte offset ignored");
    fetch(32'h0000_1000, 32'h0000_0000, "4 KB up is now inside the ROM, not a wrap");
    fetch(32'h0000_2000, 32'hdead_beef, "wrap at 8 KB");

    @(posedge clk);
    a      = 32'h0000_0000;
    a_data = 32'h0000_0008;
    @(posedge clk);
    #1;
    if (rd !== 32'hdead_beef || rd_data !== 32'h1234_5678)
      $fatal(1, "ports interfered: rd=%h rd_data=%h", rd, rd_data);

    @(posedge clk);
    a      = 32'h0000_000c;
    a_data = 32'h0000_0004;
    @(posedge clk);
    #1;
    if (rd !== 32'h9abc_def0 || rd_data !== 32'hcafe_babe)
      $fatal(1, "ports interfered on the second pair: rd=%h rd_data=%h", rd, rd_data);

    @(posedge clk);
    a      = 32'h0000_0004;
    a_data = 32'h0000_0004;
    @(posedge clk);
    #1;
    if (rd !== 32'hcafe_babe || rd_data !== 32'hcafe_babe)
      $fatal(1, "same address on both ports: rd=%h rd_data=%h", rd, rd_data);

    $display("mem_instruction_rom_tb: PASS");
    $finish;
  end
endmodule
