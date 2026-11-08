`timescale 1ns / 1ps
module cpu_mmio_bounds_tb;
  logic clk = 0, rst_n = 0, uart_rx_in = 1;
  integer index;
  always #5 clk = ~clk;
  soc_top #(.UART_CLKS_PER_BIT(4)) dut ( .clk(clk), .rst_n(rst_n), .uart_rx_in(uart_rx_in));
  function automatic [31:0] load(input [4:0] rd, input [4:0] rs, input [11:0] off);
    load = {off, rs, 3'b010, rd, 7'b0000011};
  endfunction
  task automatic send_byte(input [7:0] value);
    @(negedge clk); uart_rx_in = 0;
    repeat (4) @(negedge clk);
    for (integer bit_index = 0; bit_index < 8; bit_index++) begin
      uart_rx_in = value[bit_index];
      repeat (4) @(negedge clk);
    end
    uart_rx_in = 1;
    repeat (4) @(negedge clk);
  endtask
  initial begin
    #1;
    for (index = 0; index < 2048; index++) dut.rom.rom[index] = 32'h00000013;
    // UART receives a byte while CPU executes the initial NOPs.
    dut.rom.rom[100] = 32'h200000b7; // x1=RAM
    dut.rom.rom[101] = 32'h05b00113; // x2=0x5b
    dut.rom.rom[102] = 32'h0020a023; // store at RAM base
    dut.rom.rom[103] = 32'h200011b7; // x3=first byte beyond RAM
    dut.rom.rom[104] = 32'h0001a023; // invalid store must not alias
    dut.rom.rom[105] = load(4, 3, 0);
    dut.rom.rom[106] = load(5, 1, 0);
    dut.rom.rom[107] = 32'h50000337; // x6=UART
    dut.rom.rom[108] = load(8, 6, 12'h108); // invalid RX alias must not pop
    dut.rom.rom[109] = load(9, 6, 8); // valid RX pop
    dut.rom.rom[110] = 32'h80000537; // x10=DHT
    dut.rom.rom[111] = 32'h10252023; // sw x2,0x100(x10): invalid register write
    dut.rom.rom[112] = load(11, 10, 12'h100);
    dut.rom.rom[113] = 32'h00002637; // x12=first byte beyond ROM
    dut.rom.rom[114] = 32'h00060067; // jalr x0,x12,0
    repeat (3) @(negedge clk); rst_n = 1;
    send_byte(8'ha5);
    repeat (180) @(negedge clk);
    if (dut.cpu.rf.x[4] !== 0 || dut.cpu.rf.x[5] !== 32'h5b)
      $fatal(1, "RAM boundary aliased");
    if (dut.cpu.rf.x[8] !== 0 || dut.cpu.rf.x[9] !== 32'ha5)
      $fatal(1, "invalid UART read popped data: %h %h", dut.cpu.rf.x[8], dut.cpu.rf.x[9]);
    if (dut.serial_port.rx_inst.valid) $fatal(1, "valid UART read did not pop");
    if (dut.cpu.rf.x[11] !== 0 || dut.dht_port.busy) $fatal(1, "DHT alias decoded");
    if (dut.instr_addr < 32'h2000 || dut.instr_data !== 0)
      $fatal(1, "instruction fetch beyond ROM aliased");
    $display("cpu_mmio_bounds_tb: PASS");
    $finish;
  end
endmodule
