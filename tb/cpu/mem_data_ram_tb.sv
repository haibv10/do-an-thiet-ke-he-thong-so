`timescale 1ns/1ps

// The byte lanes are what make SB and SH work without a read-modify-write, so
// each mask bit has to reach exactly one byte of one word.
module mem_data_ram_tb;
  logic clk = 1'b0;
  logic [3:0]  we = 4'b0000;
  logic [31:0] a = 32'd0;
  logic [31:0] wd = 32'd0;
  wire  [31:0] rd;

  mem_data_ram dut (.*);

  always #5 clk = ~clk;

  // The memory reads and writes on the falling edge, so drive on the rising one.
  task automatic write_word(input logic [31:0] addr,
                            input logic [3:0] mask,
                            input logic [31:0] value);
    begin
      @(posedge clk);
      a = addr;
      we = mask;
      wd = value;
      @(posedge clk);
      we = 4'b0000;
    end
  endtask

  task automatic expect_word(input logic [31:0] addr,
                             input logic [31:0] value,
                             input string label);
    begin
      @(posedge clk);
      a = addr;
      @(posedge clk);
      #1;
      if (rd !== value)
        $fatal(1, "%s: [%h] = %h, expected %h", label, addr, rd, value);
    end
  endtask

  initial begin
    // Full word.
    write_word(32'h2000_0000, 4'b1111, 32'hdead_beef);
    expect_word(32'h2000_0000, 32'hdead_beef, "word write");

    // Each lane on its own, over a known background.
    write_word(32'h2000_0004, 4'b1111, 32'h0000_0000);
    write_word(32'h2000_0004, 4'b0001, 32'hffff_ff11);
    expect_word(32'h2000_0004, 32'h0000_0011, "lane 0");
    write_word(32'h2000_0004, 4'b0010, 32'hffff_22ff);
    expect_word(32'h2000_0004, 32'h0000_2211, "lane 1");
    write_word(32'h2000_0004, 4'b0100, 32'hff33_ffff);
    expect_word(32'h2000_0004, 32'h0033_2211, "lane 2");
    write_word(32'h2000_0004, 4'b1000, 32'h44ff_ffff);
    expect_word(32'h2000_0004, 32'h4433_2211, "lane 3");

    // A halfword mask touches two lanes and leaves the other two alone.
    write_word(32'h2000_0008, 4'b1111, 32'haaaa_aaaa);
    write_word(32'h2000_0008, 4'b0011, 32'h0000_5678);
    expect_word(32'h2000_0008, 32'haaaa_5678, "halfword mask");

    // A zero mask is a read, not a write.
    write_word(32'h2000_0000, 4'b0000, 32'h0000_0000);
    expect_word(32'h2000_0000, 32'hdead_beef, "zero mask must not write");

    // Only a[11:2] addresses the array, so the region bits and the byte offset
    // within a word are both ignored. These three are the same location.
    write_word(32'h2000_0010, 4'b1111, 32'h1234_5678);
    expect_word(32'h2000_0011, 32'h1234_5678, "byte offset ignored");
    expect_word(32'h0000_0010, 32'h1234_5678, "region bits ignored");

    // 4 KB deep, so address 0x1000 wraps onto address 0.
    write_word(32'h2000_0000, 4'b1111, 32'hcafe_0000);
    expect_word(32'h2000_1000, 32'hcafe_0000, "wrap at 4 KB");

    // Reading the address being written returns the old contents, because the
    // read is scheduled against the same edge.
    write_word(32'h2000_0020, 4'b1111, 32'h1111_1111);
    @(posedge clk);
    a = 32'h2000_0020;
    we = 4'b1111;
    wd = 32'h2222_2222;
    @(posedge clk);
    #1;
    we = 4'b0000;
    if (rd !== 32'h1111_1111)
      $fatal(1, "read during write returned %h, expected the old word", rd);
    expect_word(32'h2000_0020, 32'h2222_2222, "write did land");

    $display("mem_data_ram_tb: PASS");
    $finish;
  end
endmodule
