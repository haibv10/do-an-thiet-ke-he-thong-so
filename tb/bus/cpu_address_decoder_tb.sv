`timescale 1ns / 1ps
module cpu_address_decoder_tb;
  logic [31:0] addr = 0;
  logic [3:0] we_mask = 0;
  logic re = 0;
  wire [3:0] we_dmem;
  wire we_gpio, we_uart, we_i2c, we_spi, we_dht, re_uart, re_dht;
  logic [31:0] rd_rom = 32'h11, rd_dmem = 32'h22, rd_gpio = 32'h33;
  logic [31:0] rd_uart = 32'h44, rd_i2c = 32'h55, rd_spi = 32'h66, rd_dht = 32'h77;
  wire [31:0] rd_out;
  cpu_address_decoder dut (.*);

  task automatic check(input logic [31:0] address, input logic [31:0] value,
                       input logic [8:0] enables);
    addr = address;
    #1;
    if (rd_out !== value) $fatal(1, "read %h = %h expected %h", addr, rd_out, value);
    if ({we_dmem, we_gpio, we_uart, we_i2c, we_spi, we_dht} !== enables)
      $fatal(1, "unexpected write enables at %h", addr);
    if (re_uart !== (re && value == rd_uart) || re_dht !== (re && value == rd_dht))
      $fatal(1, "unexpected read side-effect enables at %h", addr);
  endtask

  initial begin
    we_mask = 4'hf;
    re = 1;
    check(32'h00000000, rd_rom, 0);
    check(32'h00001fff, rd_rom, 0);
    check(32'h00002000, rd_rom, 0);
    check(32'h00003fff, rd_rom, 0);
    check(32'h00004000, 0, 0);
    check(32'h20000000, rd_dmem, 9'b1111_00000);
    check(32'h20000fff, rd_dmem, 9'b1111_00000);
    check(32'h20001000, rd_dmem, 9'b1111_00000);
    check(32'h20001fff, rd_dmem, 9'b1111_00000);
    check(32'h20002000, 0, 0);
    check(32'h2ffffffc, 0, 0);
    check(32'h40000000, rd_gpio, 9'b0000_10000);
    check(32'h40000004, 0, 0);
    check(32'h50000000, rd_uart, 9'b0000_01000);
    check(32'h5000000c, rd_uart, 9'b0000_01000);
    check(32'h50000010, 0, 0);
    check(32'h50000108, 0, 0);
    check(32'h60000008, rd_i2c, 9'b0000_00100);
    check(32'h6000000c, 0, 0);
    check(32'h70000008, rd_spi, 9'b0000_00010);
    check(32'h7000000c, 0, 0);
    check(32'h80000000, rd_dht, 9'b0000_00001);
    check(32'h80000004, rd_dht, 9'b0000_00001);
    check(32'h80000008, 0, 0);
    check(32'h80000010, 0, 0);
    check(32'h80000100, 0, 0);
    check(32'h50000001, 0, 0);
    check(32'h80000001, 0, 0);
    check(32'hffffffff, 0, 0);
    we_mask = 4'b0010;
    check(32'h20000001, rd_dmem, 9'b0010_00000);
    check(32'h40000000, rd_gpio, 0);
    check(32'h80000000, rd_dht, 0);
    we_mask = 0;
    re = 0;
    check(32'h50000008, rd_uart, 0);
    check(32'h80000004, rd_dht, 0);
    $display("cpu_address_decoder_tb: PASS");
    $finish;
  end
endmodule
