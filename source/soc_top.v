module soc_top #(
  parameter UART_CLKS_PER_BIT = 234,
  parameter SPI_CLK_DIV = 1,
  parameter ROM_HEX_PATH = "rom/firmware.hex"
) (
  input  wire clk,
  input  wire rst_n,
  output wire led_out,
  input  wire uart_rx_in,
  output wire uart_tx_out,
  output wire spi_sck_out,
  output wire spi_mosi_out,
  output wire spi_cs_n_out,
  output wire spi_dc_out,
  output wire spi_rst_n_out,
  inout  wire i2c_sda,
  inout  wire i2c_scl,
  inout  wire dht11_data
);

  wire rst_n_sync;
  reset_sync reset_bridge (
    .clk      (clk),
    .rst_n_in (rst_n),
    .rst_n_out(rst_n_sync)
  );

  wire [31:0] instr_addr, instr_data, rom_instr;
  wire [31:0] mem_alu_result, mem_store_data, rom_rd;
  wire [3:0] mem_we_mask;
  wire mem_MemRead;
  wire [31:0] mem_read_data;

  cpu_top cpu (
    .clk(clk), .rst_n(rst_n_sync),
    .instr_addr(instr_addr), .instr_data(instr_data),
    .data_addr(mem_alu_result), .data_wdata(mem_store_data),
    .data_wstrb(mem_we_mask), .data_re(mem_MemRead), .data_rdata(mem_read_data)
  );

  mem_instruction_rom #(.HEX_PATH(ROM_HEX_PATH)) rom (
    .clk(clk), .a(instr_addr), .rd(rom_instr),
    .a_data(mem_alu_result), .rd_data(rom_rd)
  );
  // Fetches outside ROM return zero; this core has no instruction access trap.
  assign instr_data = (instr_addr < 32'h00004000) ? rom_instr : 32'd0;

  wire we_gpio, we_uart, we_i2c, we_spi, we_dht;
  wire uart_read, dht_read;
  wire [3:0] we_dmem;
  wire [31:0] dmem_rd, gpio_rd, uart_rd, i2c_rd, spi_rd, dht_rd;

  wire        i2c_tick;

  cpu_address_decoder bus_matrix (
    .addr   (mem_alu_result),
    .re(mem_MemRead),
    .re_uart(uart_read),
    .re_dht(dht_read),
    .we_mask(mem_we_mask),
    .we_dmem(we_dmem),
    .we_gpio(we_gpio),
    .we_uart(we_uart),
    .we_i2c (we_i2c),
    .we_spi (we_spi),
    .we_dht (we_dht),
    .rd_rom (rom_rd),
    .rd_dmem(dmem_rd),
    .rd_gpio(gpio_rd),
    .rd_uart(uart_rd),
    .rd_i2c (i2c_rd),
    .rd_spi (spi_rd),
    .rd_dht (dht_rd),
    .rd_out (mem_read_data)
  );

  mem_data_ram ram (
    .clk(clk),
    .we (we_dmem),
    .a  (mem_alu_result),
    .wd (mem_store_data),
    .rd (dmem_rd)
  );

  gpio_mmio led_controller (
    .clk  (clk),
    .rst_n(rst_n_sync),
    .we   (we_gpio),
    .a    (mem_alu_result),
    .wd   (mem_store_data),
    .rd   (gpio_rd),
    .led  (led_out)
  );

  uart_mmio #(
    .CLKS_PER_BIT(UART_CLKS_PER_BIT)
  ) serial_port (
    .clk  (clk),
    .rst_n(rst_n_sync),
    .we   (we_uart),
    .re   (uart_read),
    .a    (mem_alu_result),
    .wd   (mem_store_data),
    .rx   (uart_rx_in),
    .rd   (uart_rd),
    .tx   (uart_tx_out)
  );

  clock_enable #(
    .divider(27)
  ) i2c_clock_enable (
    .clk  (clk),
    .rst_n(rst_n_sync),
    .tick (i2c_tick)
  );

  i2c_mmio clock_port (
    .clk  (clk),
    .tick (i2c_tick),
    .rst_n(rst_n_sync),
    .we   (we_i2c),
    .a    (mem_alu_result),
    .wd   (mem_store_data),
    .rd   (i2c_rd),
    .sda  (i2c_sda),
    .scl  (i2c_scl)
  );

  spi_mmio #(
    .CLK_DIV(SPI_CLK_DIV)
  ) display_port (
    .clk      (clk),
    .rst_n    (rst_n_sync),
    .we       (we_spi),
    .a        (mem_alu_result),
    .wd       (mem_store_data),
    .rd       (spi_rd),
    .spi_sck  (spi_sck_out),
    .spi_mosi (spi_mosi_out),
    .spi_cs_n (spi_cs_n_out),
    .spi_dc   (spi_dc_out),
    .spi_rst_n(spi_rst_n_out)
  );

  dht11_mmio dht_port (
    .clk   (clk),
    .rst_n (rst_n_sync),
    .we    (we_dht),
    .re    (dht_read),
    .a     (mem_alu_result),
    .wd    (mem_store_data),
    .rd    (dht_rd),
    .dht_io(dht11_data)
  );

endmodule
