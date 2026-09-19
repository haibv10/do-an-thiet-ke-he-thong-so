module uart_tx #(
  parameter CLKS_PER_BIT = 234
) (
  input  wire        clk,        // 27 MHz
  input  wire        rst_n,
  input  wire        we,         // write enable from the address decoder
  input  wire [31:0] a,          // register offset
  input  wire [31:0] wd,         // byte to transmit, in wd[7:0]
  output wire [31:0] rd,         // status readback, rd[0] = busy
  output reg         tx          // physical UART TX pin
);

  localparam STATE_IDLE  = 2'b00;
  localparam STATE_START = 2'b01;
  localparam STATE_DATA  = 2'b10;
  localparam STATE_STOP  = 2'b11;

  reg [1:0]  state;
  reg [15:0] clk_count;
  reg [2:0]  bit_idx;
  reg [7:0]  tx_data;
  reg        busy;

  // The CPU reads the status register at offset 0x04
  assign rd = (a[7:0] == 8'h04) ? {31'd0, busy} : 32'd0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= STATE_IDLE;
      tx        <= 1'b1; // UART line idles high
      busy      <= 1'b0;
      clk_count <= 16'd0;
      bit_idx   <= 3'd0;
      tx_data   <= 8'd0;
    end else begin
      case (state)
        STATE_IDLE: begin
          tx <= 1'b1;
          if (we && (a[7:0] == 8'h00) && !busy) begin
            tx_data   <= wd[7:0]; // latch the byte to send
            busy      <= 1'b1;
            state     <= STATE_START;
            clk_count <= 16'd0;
          end else begin
            busy <= 1'b0;
          end
        end

        STATE_START: begin
          tx <= 1'b0; // drive the start bit
          if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 16'd0;
            state     <= STATE_DATA;
            bit_idx   <= 3'd0;
          end
        end

        STATE_DATA: begin
          tx <= tx_data[bit_idx]; // shift out bit 0 through bit 7
          if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 16'd0;
            if (bit_idx < 3'd7) begin
              bit_idx <= bit_idx + 1'b1;
            end else begin
              state   <= STATE_STOP;
            end
          end
        end

        STATE_STOP: begin
          tx <= 1'b1; // drive the stop bit
          if (clk_count < CLKS_PER_BIT - 1) begin
            clk_count <= clk_count + 1'b1;
          end else begin
            clk_count <= 16'd0;
            busy      <= 1'b0;
            state     <= STATE_IDLE;
          end
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
