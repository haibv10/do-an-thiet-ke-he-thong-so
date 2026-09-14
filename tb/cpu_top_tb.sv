`timescale 1ns/1ps

module cpu_top_tb;
  localparam integer CLKS_PER_UART_BIT = 234;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic btn_in = 1'b0;
  logic uart_rx_in = 1'b1;
  logic led_out;
  logic uart_tx_out;
  logic [7:0] uart_data;
  logic [7:0] uart_echo_data;
  integer index;
  integer stall_count = 0;

  always #18.5 clk = ~clk;

  cpu_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .led_out(led_out),
    .btn_in(btn_in),
    .uart_rx_in(uart_rx_in),
    .uart_tx_out(uart_tx_out)
  );

  always @(posedge clk) begin
    if (rst_n && dut.stall)
      stall_count <= stall_count + 1;
  end

  function automatic logic [31:0] encode_i(
    input logic [11:0] immediate,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_i = {immediate, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] encode_r(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] encode_s(
    input logic [11:0] immediate,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [6:0] opcode
  );
    encode_s = {immediate[11:5], rs2, rs1, funct3,
                immediate[4:0], opcode};
  endfunction

  function automatic logic [31:0] encode_b(
    input logic [12:0] immediate,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [6:0] opcode
  );
    encode_b = {immediate[12], immediate[10:5], rs2, rs1, funct3,
                immediate[4:1], immediate[11], opcode};
  endfunction

  function automatic logic [31:0] encode_u(
    input logic [19:0] immediate,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_u = {immediate, rd, opcode};
  endfunction

  function automatic logic [31:0] encode_j(
    input logic [20:0] immediate,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    encode_j = {immediate[20], immediate[10:1], immediate[11],
                immediate[19:12], rd, opcode};
  endfunction

  task automatic send_uart_byte(input logic [7:0] value);
    integer send_index;
    begin
      @(negedge clk) uart_rx_in = 1'b0;
      repeat (CLKS_PER_UART_BIT) @(negedge clk);
      for (send_index = 0; send_index < 8; send_index = send_index + 1) begin
        uart_rx_in = value[send_index];
        repeat (CLKS_PER_UART_BIT) @(negedge clk);
      end
      uart_rx_in = 1'b1;
      repeat (CLKS_PER_UART_BIT) @(negedge clk);
    end
  endtask

  task automatic capture_uart_byte(output logic [7:0] value);
    integer capture_index;
    begin
      capture_index = 0;
      while ((uart_tx_out !== 1'b0) && (capture_index < 500)) begin
        @(posedge clk);
        capture_index = capture_index + 1;
      end
      if (uart_tx_out !== 1'b0)
        $fatal(1, "timeout waiting for UART start bit");

      repeat (CLKS_PER_UART_BIT / 2) @(posedge clk);
      if (uart_tx_out !== 1'b0) $fatal(1, "UART start bit");
      for (capture_index = 0; capture_index < 8;
           capture_index = capture_index + 1) begin
        repeat (CLKS_PER_UART_BIT) @(posedge clk);
        value[capture_index] = uart_tx_out;
      end
      repeat (CLKS_PER_UART_BIT) @(posedge clk);
      if (uart_tx_out !== 1'b1) $fatal(1, "UART stop bit");
    end
  endtask

  initial begin
    #1;
    for (index = 0; index < 1024; index = index + 1)
      dut.rom.rom[index] = 32'h0000_0013;

    dut.rom.rom[0]  = encode_u(20'h20000, 5'd4, 7'b0110111);
    dut.rom.rom[1]  = encode_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011);
    dut.rom.rom[2]  = encode_i(12'd3, 5'd1, 3'b000, 5'd2, 7'b0010011);
    dut.rom.rom[3]  = encode_r(7'd0, 5'd1, 5'd2, 3'b000, 5'd3,
                               7'b0110011);
    dut.rom.rom[4]  = encode_s(12'd0, 5'd3, 5'd4, 3'b010, 7'b0100011);
    dut.rom.rom[5]  = encode_i(12'd0, 5'd4, 3'b010, 5'd5, 7'b0000011);
    dut.rom.rom[6]  = encode_i(12'd1, 5'd5, 3'b000, 5'd6, 7'b0010011);
    dut.rom.rom[7]  = encode_i(12'hfff, 5'd0, 3'b000, 5'd14,
                               7'b0010011);
    dut.rom.rom[8]  = encode_s(12'd4, 5'd14, 5'd4, 3'b000, 7'b0100011);
    dut.rom.rom[9]  = encode_i(12'd4, 5'd4, 3'b100, 5'd15, 7'b0000011);
    dut.rom.rom[10] = encode_i(12'd4, 5'd4, 3'b000, 5'd16, 7'b0000011);
    dut.rom.rom[11] = encode_i(12'hffe, 5'd0, 3'b000, 5'd17,
                               7'b0010011);
    dut.rom.rom[12] = encode_s(12'd6, 5'd17, 5'd4, 3'b001, 7'b0100011);
    dut.rom.rom[13] = encode_i(12'd6, 5'd4, 3'b101, 5'd18, 7'b0000011);
    dut.rom.rom[14] = encode_i(12'd6, 5'd4, 3'b001, 5'd19, 7'b0000011);
    dut.rom.rom[15] = encode_b(13'd8, 5'd3, 5'd6, 3'b001, 7'b1100011);
    dut.rom.rom[16] = encode_i(12'd1, 5'd0, 3'b000, 5'd7, 7'b0010011);
    dut.rom.rom[17] = encode_u(20'h40000, 5'd8, 7'b0110111);
    dut.rom.rom[18] = encode_i(12'd1, 5'd0, 3'b000, 5'd9, 7'b0010011);
    dut.rom.rom[19] = encode_s(12'd0, 5'd9, 5'd8, 3'b010, 7'b0100011);
    dut.rom.rom[20] = encode_j(21'd8, 5'd10, 7'b1101111);
    dut.rom.rom[21] = encode_i(12'd1, 5'd0, 3'b000, 5'd11, 7'b0010011);
    dut.rom.rom[22] = encode_u(20'h50000, 5'd12, 7'b0110111);
    dut.rom.rom[23] = encode_i(12'd72, 5'd0, 3'b000, 5'd13,
                               7'b0010011);
    dut.rom.rom[24] = encode_s(12'd0, 5'd13, 5'd12, 3'b010,
                               7'b0100011);
    dut.rom.rom[25] = encode_i(12'd4, 5'd12, 3'b010, 5'd20,
                               7'b0000011);
    dut.rom.rom[26] = encode_i(12'd2, 5'd20, 3'b111, 5'd20,
                               7'b0010011);
    dut.rom.rom[27] = encode_b(13'h1ff8, 5'd0, 5'd20, 3'b000,
                               7'b1100011);
    dut.rom.rom[28] = encode_i(12'd8, 5'd12, 3'b010, 5'd21,
                               7'b0000011);
    dut.rom.rom[29] = encode_s(12'd0, 5'd21, 5'd12, 3'b010,
                               7'b0100011);
    dut.rom.rom[30] = encode_j(21'd0, 5'd0, 7'b1101111);

    repeat (2) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;

    capture_uart_byte(uart_data);

    if (dut.rf.x[1] !== 32'd5 || dut.rf.x[2] !== 32'd8 ||
        dut.rf.x[3] !== 32'd13) $fatal(1, "forwarding result");
    if (dut.ram.ram[0] !== 32'd13 || dut.rf.x[6] !== 32'd14)
      $fatal(1, "load-use result");
    if (dut.ram.ram[1][7:0] !== 8'hff ||
        dut.ram.ram[1][31:16] !== 16'hfffe ||
        dut.rf.x[15] !== 32'h0000_00ff ||
        dut.rf.x[16] !== 32'hffff_ffff ||
        dut.rf.x[18] !== 32'h0000_fffe ||
        dut.rf.x[19] !== 32'hffff_fffe)
      $fatal(1,
             "subword RAM=%h x15=%h x16=%h x18=%h x19=%h",
             dut.ram.ram[1], dut.rf.x[15], dut.rf.x[16],
             dut.rf.x[18], dut.rf.x[19]);
    if (stall_count < 1) $fatal(1, "load-use stall was not observed");
    if (dut.rf.x[7] !== 32'd0) $fatal(1, "branch flush");
    if (dut.rf.x[10] !== 32'd84 || dut.rf.x[11] !== 32'd0)
      $fatal(1, "JAL link or flush");
    if (led_out !== 1'b1) $fatal(1, "GPIO MMIO write");
    if (uart_data !== 8'h48) $fatal(1, "UART data=%h", uart_data);

    send_uart_byte(8'ha5);
    capture_uart_byte(uart_echo_data);
    if (uart_echo_data !== 8'ha5)
      $fatal(1, "UART echo data=%h", uart_echo_data);
    if (dut.serial_port.rx_inst.valid)
      $fatal(1, "UART RX valid did not clear after CPU load");

    $display("cpu_top_tb: PASS");
    $finish;
  end
endmodule
