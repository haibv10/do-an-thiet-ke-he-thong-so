`timescale 1ns / 1ps

// Runs rom/firmware.hex and expects BOOT OK: startup copied .data and cleared .bss.
module cpu_firmware_boot_tb;
  localparam integer BIT = 234;  // clocks per UART bit at 115200 baud
  localparam integer LEN = 7;
  localparam [LEN*8-1:0] BANNER = "BOOT OK";

  logic clk = 0, rst_n = 0;
  wire uart_tx_out;
  logic [7:0] received;
  always #18.5 clk = ~clk;

  soc_top dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .uart_rx_in (1'b1),
    .uart_tx_out(uart_tx_out)
  );

  initial #20_000_000 $fatal(1, "timeout");

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1;

    for (int n = 0; n < LEN; n++) begin
      @(negedge uart_tx_out);
      repeat (BIT + BIT / 2) @(posedge clk);
      for (int b = 0; b < 8; b++) begin
        received[b] = uart_tx_out;
        repeat (BIT) @(posedge clk);
      end
      if (received !== BANNER[(LEN-1-n)*8+:8])
        $fatal(1, "banner char %0d = '%c', expected '%c'", n, received, BANNER[(LEN-1-n)*8+:8]);
    end

    $display("cpu_firmware_boot_tb: PASS (%s)", BANNER);
    $finish;
  end
endmodule
