module spi_master #(
  parameter CLK_DIV = 2   // sck half-period in clk cycles; sck = clk / (2 * CLK_DIV)
) (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       start,
  input  wire [7:0] tx_byte,
  output reg        busy,
  output reg        sck,
  output reg        mosi
);

  // SPI mode 0, MSB first. mosi changes while sck is low; the slave samples on
  // the rising edge. There is no miso port: the ST7735 breakout brings only
  // SDA out to the header, so the link is write-only and a receive path would
  // be unconnected logic.

  localparam STATE_IDLE     = 2'b00;
  localparam STATE_SCK_LOW  = 2'b01;
  localparam STATE_SCK_HIGH = 2'b10;
  localparam STATE_FINISH   = 2'b11; // trailing sck-low half period

  reg [1:0]  state;
  reg [15:0] half_count;
  reg [2:0]  bit_idx;
  reg [7:0]  shift_data;

  wire half_period_done = (half_count >= CLK_DIV - 1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= STATE_IDLE;
      busy       <= 1'b0;
      sck        <= 1'b0; // mode 0 idles low
      mosi       <= 1'b0;
      half_count <= 16'd0;
      bit_idx    <= 3'd0;
      shift_data <= 8'd0;
    end else begin
      case (state)
        STATE_IDLE: begin
          sck <= 1'b0;
          if (start && !busy) begin
            shift_data <= tx_byte;
            mosi       <= tx_byte[7]; // settle the MSB before the first rising edge
            bit_idx    <= 3'd7;
            busy       <= 1'b1;
            half_count <= 16'd0;
            state      <= STATE_SCK_LOW;
          end
        end

        STATE_SCK_LOW: begin
          sck <= 1'b0;
          if (!half_period_done) begin
            half_count <= half_count + 1'b1;
          end else begin
            half_count <= 16'd0;
            state      <= STATE_SCK_HIGH;
          end
        end

        STATE_SCK_HIGH: begin
          sck <= 1'b1;
          if (!half_period_done) begin
            half_count <= half_count + 1'b1;
          end else begin
            half_count <= 16'd0;
            if (bit_idx == 3'd0) begin
              state <= STATE_FINISH;
            end else begin
              bit_idx <= bit_idx - 1'b1;
              mosi    <= shift_data[bit_idx - 1'b1];
              state   <= STATE_SCK_LOW;
            end
          end
        end

        // busy stays set for one more half period so that the last bit gets a
        // full sck-high time and cs_n or dc, which software moves as soon as
        // busy clears, cannot change while sck is still high.
        STATE_FINISH: begin
          sck <= 1'b0;
          if (!half_period_done) begin
            half_count <= half_count + 1'b1;
          end else begin
            half_count <= 16'd0;
            busy       <= 1'b0;
            state      <= STATE_IDLE;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
