`timescale 1ns/1ps
module i2c_lcd_20x4_refresh_tb;
  logic clk_1MHz=0, rst_n=0, ena=0, done_write=0;
  logic [159:0] row1="LCD 20x4 READY      ";
  logic [159:0] row2="UART AND I2C MMIO   ";
  logic [159:0] row3="LINE THREE          ";
  logic [159:0] row4="LINE FOUR           ";
  logic [7:0] data; logic cmd_data, ena_write;
  logic [7:0] writes[0:88]; logic types[0:88]; integer count=0, i;
  always #5 clk_1MHz=~clk_1MHz;
  i2c_lcd_20x4_refresh dut (.*);
  always @(posedge clk_1MHz) done_write <= ena_write;
  always @(posedge clk_1MHz) if (ena_write && count < 89) begin
    writes[count]=data; types[count]=cmd_data; count=count+1;
  end
  initial begin
    #1000000;
    $fatal(1, "timeout count=%0d state=%0d ptr=%0d cnt=%0d", count,
           dut.state, dut.ptr, dut.cnt);
  end
  initial begin
    for (i=0;i<89;i=i+1) begin writes[i]=0; types[i]=0; end
    repeat(3) @(posedge clk_1MHz); rst_n=1;
    @(negedge clk_1MHz) ena=1; @(negedge clk_1MHz) ena=0;
    wait(count==89); @(posedge clk_1MHz);
    if (writes[0]!==8'h02 || writes[1]!==8'h28 || writes[5]!==8'h80 ||
        writes[26]!==8'hC0 || writes[47]!==8'h94 || writes[68]!==8'hD4)
      $fatal(1,"unexpected LCD 20x4 command sequence");
    if (writes[6]!=="L" || writes[27]!=="U" || writes[48]!=="L" || writes[69]!=="L")
      $fatal(1,"unexpected LCD row data");
    if (types[5]!==0 || types[6]!==1 || types[26]!==0 || types[27]!==1 ||
        types[47]!==0 || types[48]!==1 || types[68]!==0 || types[69]!==1)
      $fatal(1,"unexpected command/data classification");
    $display("i2c_lcd_20x4_refresh_tb: PASS"); $finish;
  end
endmodule
