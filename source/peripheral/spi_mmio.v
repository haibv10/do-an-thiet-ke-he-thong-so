module spi_mmio #(
  parameter CLK_DIV = 2
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output reg  [31:0] rd,
  output wire        spi_sck,
  output wire        spi_mosi,
  output reg         spi_cs_n,
  output reg         spi_dc,
  output reg         spi_rst_n
);

  wire busy;
  wire start = we && (a[7:0] == 8'h00);
  wire ctrl_we = we && (a[7:0] == 8'h08);

  spi_master #(
    .CLK_DIV(CLK_DIV)
  ) master_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .tx_byte(wd[7:0]),
    .busy(busy),
    .sck(spi_sck),
    .mosi(spi_mosi)
  );

  // cs_n, dc and the panel reset are held in software rather than sequenced by
  // the shift engine: an ST7735 command and its parameters are one chip select
  // frame spanning several bytes, and dc has to change between them.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_cs_n  <= 1'b1; // deselected
      spi_dc    <= 1'b0; // command
      spi_rst_n <= 1'b0; // panel held in reset until firmware releases it
    end else if (ctrl_we) begin
      spi_cs_n  <= wd[0];
      spi_dc    <= wd[1];
      spi_rst_n <= wd[2];
    end
  end

  always @(*) begin
    rd = 32'd0;
    case (a[7:0])
      8'h04: rd[0] = busy;
      8'h08: rd[2:0] = {spi_rst_n, spi_dc, spi_cs_n};
      default: ;
    endcase
  end

endmodule
