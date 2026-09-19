module uart_rx #(
  parameter CLKS_PER_BIT = 234
) (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       rx,
  input  wire       clear,
  output reg  [7:0] data,
  output reg        valid
);

  localparam HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

  localparam STATE_IDLE  = 2'b00;
  localparam STATE_START = 2'b01;
  localparam STATE_DATA  = 2'b10;
  localparam STATE_STOP  = 2'b11;

  reg [1:0]  state;
  reg [15:0] clk_count;
  reg [2:0]  bit_idx;
  reg [7:0]  shift_data;
  reg        rx_meta;
  reg        rx_sync;

  wire byte_complete = (state == STATE_STOP) &&
                       (clk_count == CLKS_PER_BIT - 1) && rx_sync;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
    end else begin
      rx_meta <= rx;
      rx_sync <= rx_meta;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= STATE_IDLE;
      clk_count  <= 16'd0;
      bit_idx    <= 3'd0;
      shift_data <= 8'd0;
    end else begin
      case (state)
        STATE_IDLE: begin
          clk_count <= 16'd0;
          bit_idx   <= 3'd0;
          if (!rx_sync)
            state <= STATE_START;
        end

        STATE_START: begin
          if (clk_count == HALF_CLKS_PER_BIT - 1) begin
            clk_count <= 16'd0;
            state <= rx_sync ? STATE_IDLE : STATE_DATA;
          end else begin
            clk_count <= clk_count + 1'b1;
          end
        end

        STATE_DATA: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 16'd0;
            shift_data[bit_idx] <= rx_sync;
            if (bit_idx == 3'd7) begin
              state <= STATE_STOP;
            end else begin
              bit_idx <= bit_idx + 1'b1;
            end
          end else begin
            clk_count <= clk_count + 1'b1;
          end
        end

        STATE_STOP: begin
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 16'd0;
            state <= STATE_IDLE;
          end else begin
            clk_count <= clk_count + 1'b1;
          end
        end

        default: begin
          state <= STATE_IDLE;
          clk_count <= 16'd0;
          bit_idx <= 3'd0;
        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data  <= 8'd0;
      valid <= 1'b0;
    end else if (byte_complete) begin
      data  <= shift_data;
      valid <= 1'b1;
    end else if (clear) begin
      valid <= 1'b0;
    end
  end

endmodule
