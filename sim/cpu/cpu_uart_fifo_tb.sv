`timescale 1ns/1ps

module cpu_uart_fifo_tb;
  localparam integer CLKS_PER_BIT = 8;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic uart_rx_in = 1'b1;
  wire led_out;
  wire uart_tx_out;
  tri1 i2c_sda;
  tri1 i2c_scl;
  integer word_index;

  always #5 clk = ~clk;

  cpu_top #(
    .UART_CLKS_PER_BIT(CLKS_PER_BIT)
  ) dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out),
    .uart_rx_in(uart_rx_in), .uart_tx_out(uart_tx_out)
  );

  task automatic send_byte(input logic [7:0] value);
    integer bit_index;
    @(negedge clk) uart_rx_in = 1'b0;
    repeat (CLKS_PER_BIT) @(negedge clk);
    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
      uart_rx_in = value[bit_index];
      repeat (CLKS_PER_BIT) @(negedge clk);
    end
    uart_rx_in = 1'b1;
    repeat (CLKS_PER_BIT) @(negedge clk);
  endtask

  initial begin
    #1;
    for (word_index = 0; word_index < 1024; word_index = word_index + 1)
      dut.rom.rom[word_index] = 32'h0000_0013;

    // x1 = UART base; wait for two frames, then read FIFO twice.
    dut.rom.rom[0] = 32'h5000_00b7; // lui  x1, 0x50000
    dut.rom.rom[1] = 32'h3e80_0213; // addi x4, x0, 1000
    dut.rom.rom[2] = 32'hfff2_0213; // addi x4, x4, -1
    dut.rom.rom[3] = 32'hfe02_1ee3; // bne  x4, x0, -4
    dut.rom.rom[4] = 32'h0080_a103; // lw   x2, 8(x1)
    dut.rom.rom[5] = 32'h0080_a183; // lw   x3, 8(x1)
    dut.rom.rom[6] = 32'h0000_006f; // jal  x0, 0

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    send_byte(8'ha5);
    send_byte(8'hc3);
    repeat (5000) @(posedge clk);

    if (dut.rf.x[2] !== 32'h0000_00a5 || dut.rf.x[3] !== 32'h0000_00c3)
      $fatal(1, "CPU FIFO reads: x2=%h x3=%h", dut.rf.x[2], dut.rf.x[3]);
    if (dut.serial_port.rx_inst.level !== 5'd0)
      $fatal(1, "CPU did not drain FIFO: level=%d", dut.serial_port.rx_inst.level);

    $display("cpu_uart_fifo_tb: PASS");
    $finish;
  end
endmodule
