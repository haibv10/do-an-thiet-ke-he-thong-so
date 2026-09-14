`timescale 1ns/1ps

module lcd_display_tb;
  logic clk_1MHz = 1'b0;
  logic rst_n = 1'b0;
  logic ena = 1'b0;
  logic done_write = 1'b0;
  logic [127:0] row1 = "HELLO, FPGA!    ";
  logic [127:0] row2 = "I2C LCD TEST   ";
  logic [7:0] data;
  logic cmd_data;
  logic ena_write;
  logic [7:0] writes [0:6];
  logic write_cmd_data [0:6];
  integer write_count = 0;
  integer index;

  always #5 clk_1MHz = ~clk_1MHz;

  lcd_display dut (.*);

  // The lower-layer I2C/LCD writer completes each request one clock later.
  always @(posedge clk_1MHz)
    done_write <= ena_write;

  always @(posedge clk_1MHz)
    if (ena_write && write_count < 7) begin
      writes[write_count] = data;
      write_cmd_data[write_count] = cmd_data;
      write_count = write_count + 1;
    end

  initial begin
    for (index = 0; index < 7; index = index + 1) begin
      writes[index] = 8'h00;
      write_cmd_data[index] = 1'b0;
    end

    repeat (3) @(posedge clk_1MHz);
    rst_n = 1'b1;
    @(negedge clk_1MHz);
    ena = 1'b1;
    @(negedge clk_1MHz);
    ena = 1'b0;

    wait (write_count == 7);
    @(posedge clk_1MHz);

    if (writes[0] !== 8'h02 || writes[1] !== 8'h28 ||
        writes[2] !== 8'h0C || writes[3] !== 8'h06 ||
        writes[4] !== 8'h01 || writes[5] !== 8'h80 ||
        writes[6] !== "H")
      $fatal(1, "unexpected LCD initialization sequence");
    if (write_cmd_data[0] !== 1'b0 || write_cmd_data[5] !== 1'b0 ||
        write_cmd_data[6] !== 1'b1)
      $fatal(1, "unexpected command/data classification");

    $display("lcd_display_tb: PASS");
    $finish;
  end
endmodule
