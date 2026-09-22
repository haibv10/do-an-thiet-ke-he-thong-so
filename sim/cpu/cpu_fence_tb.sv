`timescale 1ns/1ps

module cpu_fence_tb;
  localparam logic [31:0] NOP = 32'h0000_0013;
  localparam logic [31:0] FENCE = 32'h0000_000f;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire led_out;
  wire uart_tx_out;
  tri1 i2c_sda;
  tri1 i2c_scl;
  integer index;
  integer fence_count = 0;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out),
    .i2c_sda(i2c_sda), .i2c_scl(i2c_scl)
  );

  always @(posedge clk)
    if (rst_n && dut.id_Fence) fence_count <= fence_count + 1;

  initial begin
    #1;
    for (index = 0; index < 2048; index = index + 1)
      dut.rom.rom[index] = NOP;

    dut.rom.rom[0] = 32'h2000_00b7; // lui x1, 0x20000
    dut.rom.rom[1] = 32'h05a0_0113; // addi x2, x0, 90
    dut.rom.rom[2] = 32'h0020_a023; // sw x2, 0(x1)
    dut.rom.rom[3] = FENCE;
    dut.rom.rom[4] = 32'h0000_a183; // lw x3, 0(x1)
    dut.rom.rom[5] = 32'h0000_006f; // jal x0, 0

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    repeat (30) @(posedge clk);

    if (dut.rf.x[3] !== 32'd90)
      $fatal(1, "load after FENCE = %h", dut.rf.x[3]);
    if (fence_count !== 1)
      $fatal(1, "FENCE decoded %0d times", fence_count);

    $display("cpu_fence_tb: PASS");
    $finish;
  end
endmodule
