module uart_mmio #(
  parameter CLKS_PER_BIT = 234,
  parameter RX_FIFO_DEPTH = 16
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
  wire        rx_overrun;
  wire [$clog2(RX_FIFO_DEPTH + 1)-1:0] rx_level;
  wire        rx_pop = re && (a[7:0] == 8'h08);
  wire        rx_clear_overrun = we && (a[7:0] == 8'h0c) && wd[0];

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
    .CLKS_PER_BIT(CLKS_PER_BIT),
    .FIFO_DEPTH(RX_FIFO_DEPTH)
  ) rx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rx(rx),
    .pop(rx_pop),
    .clear_overrun(rx_clear_overrun),
    .data(rx_data),
    .valid(rx_valid),
    .overrun(rx_overrun),
    .level(rx_level)
  );

  always @(*) begin
    rd = 32'd0;
    case (a[7:0])
      8'h04: begin
        rd[0] = tx_rd[0];
        rd[1] = rx_valid;
        rd[2] = rx_overrun;
        rd[7:3] = rx_level;
      end
      8'h08: rd = {24'd0, rx_data};
      default: ;
    endcase
  end

endmodule
