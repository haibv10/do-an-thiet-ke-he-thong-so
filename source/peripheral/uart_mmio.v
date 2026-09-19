module uart_mmio #(
  parameter CLKS_PER_BIT = 234
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire        re,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  input  wire        rx,
  output reg  [31:0] rd,
  output wire        tx
);

  wire [31:0] tx_rd;
  wire [7:0]  rx_data;
  wire        rx_valid;
  wire        rx_clear = re && (a[7:0] == 8'h08);

  uart_tx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) tx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .we(we),
    .a(a),
    .wd(wd),
    .rd(tx_rd),
    .tx(tx)
  );

  uart_rx #(
    .CLKS_PER_BIT(CLKS_PER_BIT)
  ) rx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .clear(rx_clear),
    .data(rx_data),
    .valid(rx_valid)
  );

  always @(*) begin
    case (a[7:0])
      8'h04: rd = {30'd0, rx_valid, tx_rd[0]};
      8'h08: rd = {24'd0, rx_data};
      default: rd = 32'd0;
    endcase
  end

endmodule
