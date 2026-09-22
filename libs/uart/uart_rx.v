module uart_rx #(
  parameter CLKS_PER_BIT = 234,
  parameter FIFO_DEPTH = 16
) (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       rx,
  input  wire       pop,
  input  wire       clear_overrun,
  output wire [7:0] data,
  output wire       valid,
  output reg        overrun,
  output wire [$clog2(FIFO_DEPTH + 1)-1:0] level
);

  localparam HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;
  localparam PTR_WIDTH = $clog2(FIFO_DEPTH);
  localparam LEVEL_WIDTH = $clog2(FIFO_DEPTH + 1);

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
  reg [7:0]  fifo [0:FIFO_DEPTH-1];
  reg [PTR_WIDTH-1:0] read_ptr;
  reg [PTR_WIDTH-1:0] write_ptr;
  reg [LEVEL_WIDTH-1:0] count;

  wire byte_complete = (state == STATE_STOP) &&
                       (clk_count == CLKS_PER_BIT - 1) && rx_sync;
  wire fifo_empty = (count == {LEVEL_WIDTH{1'b0}});
  wire fifo_full = (count == FIFO_DEPTH);
  wire do_pop = pop && !fifo_empty;
  wire do_push = byte_complete && (!fifo_full || do_pop);

  assign data = fifo_empty ? 8'd0 : fifo[read_ptr];
  assign valid = !fifo_empty;
  assign level = count;

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

  // The FIFO keeps arrival order and drops only a byte that cannot be stored.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      read_ptr <= {PTR_WIDTH{1'b0}};
      write_ptr <= {PTR_WIDTH{1'b0}};
      count <= {LEVEL_WIDTH{1'b0}};
      overrun <= 1'b0;
    end else begin
      if (do_push) begin
        fifo[write_ptr] <= shift_data;
        write_ptr <= write_ptr + 1'b1;
      end

      if (do_pop)
        read_ptr <= read_ptr + 1'b1;

      case ({do_push, do_pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase

      if (byte_complete && fifo_full && !do_pop)
        overrun <= 1'b1;
      else if (clear_overrun)
        overrun <= 1'b0;
    end
  end

endmodule
