`timescale 1ns/1ps

// Two read ports over one image: the fetch port feeds IF, the data port is how
// loads reach .rodata and the load image of .data.
module mem_instruction_rom_tb;
  logic clk = 1'b0;
  logic [31:0] a = 32'd0;
  wire  [31:0] rd;
  logic [31:0] a_data = 32'd0;
  wire  [31:0] rd_data;

  // The fixture holds four words on purpose. $readmemh warns that the file is
  // shorter than the array, and that warning is the point: it is the condition
  // under which the zero-fill loop in mem_instruction_rom.v has to do its job. Padding the
  // fixture to 1024 words would silence the warning and delete the test.
  mem_instruction_rom #(.HEX_PATH("sim/support/imem_test.hex")) dut (.*);

  always #5 clk = ~clk;

  task automatic fetch(input logic [31:0] addr,
                       input logic [31:0] value,
                       input string label);
    begin
      @(posedge clk);
      a = addr;
      @(posedge clk);
      #1;
      if (rd !== value)
        $fatal(1, "%s: fetch [%h] = %h, expected %h", label, addr, rd, value);
    end
  endtask

  initial begin
    // The image supplies the first four words.
    fetch(32'h0000_0000, 32'hdead_beef, "word 0");
    fetch(32'h0000_0004, 32'hcafe_babe, "word 1");
    fetch(32'h0000_0008, 32'h1234_5678, "word 2");
    fetch(32'h0000_000c, 32'h9abc_def0, "word 3");

    // Past the end of the image the array must read as zero, not x, or a stray
    // load poisons the pipeline.
    fetch(32'h0000_0010, 32'h0000_0000, "past the end of the image");
    fetch(32'h0000_0ffc, 32'h0000_0000, "last word of the ROM");

    // Only a[11:2] addresses the array: the byte offset and the region bits are
    // both ignored, and 4 KB up wraps onto word 0.
    fetch(32'h0000_0002, 32'hdead_beef, "byte offset ignored");
    fetch(32'h0000_1000, 32'hdead_beef, "wrap at 4 KB");

    // The two ports are independent and read in the same cycle.
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
      $fatal(1, "ports interfered on the second pair: rd=%h rd_data=%h",
             rd, rd_data);

    // Both ports may read the same word at once.
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
