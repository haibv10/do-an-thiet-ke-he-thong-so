`timescale 1ns/1ps

// End-to-end check of the real sw/firmware.hex image on the real SoC.
//
// The banner the firmware prints is a self-check of the startup code:
//   "BOOT "     comes from a .rodata string, so the ROM data window works
//   "5A5A5A5A"  is data_marker, so startup.s copied .data out of ROM
//   "00000000"  is bss_marker, so startup.s cleared .bss
// The hex digits themselves are looked up in a .rodata table, and every address
// in startup.s is formed with AUIPC.
module firmware_boot_tb;
  localparam integer CLKS_PER_UART_BIT = 234;
  localparam integer BANNER_LEN = 24;
  // Octal escapes for CR and LF: plain \r is not portable in a Verilog string.
  localparam [BANNER_LEN*8-1:0] BANNER = "BOOT 5A5A5A5A 00000000\015\012";

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  wire  led_out;
  wire  uart_tx_out;
  tri1  i2c_sda;
  tri1  i2c_scl;
  logic [7:0] received;
  integer index;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk), .rst_n(rst_n), .led_out(led_out), .btn_in(1'b0),
    .uart_rx_in(1'b1), .uart_tx_out(uart_tx_out),
    .i2c_sda(i2c_sda), .i2c_scl(i2c_scl)
  );

  task automatic capture_uart_byte(output logic [7:0] value);
    integer wait_index;
    begin
      wait_index = 0;
      while ((uart_tx_out !== 1'b0) && (wait_index < 200000)) begin
        @(posedge clk);
        wait_index = wait_index + 1;
      end
      if (uart_tx_out !== 1'b0)
        $fatal(1, "timeout waiting for a UART start bit");

      repeat (CLKS_PER_UART_BIT / 2) @(posedge clk);
      if (uart_tx_out !== 1'b0) $fatal(1, "UART start bit");
      for (wait_index = 0; wait_index < 8; wait_index = wait_index + 1) begin
        repeat (CLKS_PER_UART_BIT) @(posedge clk);
        value[wait_index] = uart_tx_out;
      end
      repeat (CLKS_PER_UART_BIT) @(posedge clk);
      if (uart_tx_out !== 1'b1) $fatal(1, "UART stop bit");
    end
  endtask

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    for (index = 0; index < BANNER_LEN; index = index + 1) begin
      capture_uart_byte(received);
      if (received !== BANNER[(BANNER_LEN - index) * 8 - 1 -: 8])
        $fatal(1, "banner byte %0d = %h ('%c'), expected %h ('%c')",
               index, received, received,
               BANNER[(BANNER_LEN - index) * 8 - 1 -: 8],
               BANNER[(BANNER_LEN - index) * 8 - 1 -: 8]);
    end

    $display("firmware_boot_tb: PASS (banner \"BOOT 5A5A5A5A 00000000\")");
    $finish;
  end
endmodule
