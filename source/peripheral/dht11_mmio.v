// DHT11 single-wire controller. The host pulls the data line low for 18 ms,
// releases it, then samples the 40 data bits at 40 us into each high pulse.
// A 4.7k pull-up to 3.3 V is required on dht_io.
module dht11_mmio (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire        re,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output reg  [31:0] rd,
  inout  wire        dht_io
);
  localparam [3:0] IDLE = 4'd0, START_LOW = 4'd1, RELEASE_WAIT = 4'd2,
                   RESP_LOW = 4'd3, RESP_HIGH = 4'd4, BIT_LOW = 4'd5,
                   BIT_SAMPLE = 4'd6, BIT_END = 4'd7, FINISH = 4'd8,
                   FAILED = 4'd9, RESP_END = 4'd10;
  localparam [31:0] START_CYCLES = 32'd486000; // 18 ms at 27 MHz
  localparam [31:0] RELEASE_CYCLES = 32'd810;  // 30 us
  localparam [31:0] SAMPLE_CYCLES = 32'd1080;   // 40 us
  localparam [31:0] TIMEOUT_CYCLES = 32'd5400;  // 200 us

  reg [3:0] state;
  reg [31:0] timer;
  reg [2:0] sync_line;
  reg [39:0] bits;
  reg [5:0] bit_count;
  reg sample_bit;
  reg busy;
  reg valid;
  reg fault;
  reg drive_low;
  reg [31:0] measurement;
  wire [39:0] completed_bits = {bits[38:0], sample_bit};
  wire [7:0] checksum = completed_bits[39:32] + completed_bits[31:24] +
                        completed_bits[23:16] + completed_bits[15:8];

  assign dht_io = drive_low ? 1'b0 : 1'bz;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) sync_line <= 3'b111;
    else sync_line <= {sync_line[1:0], dht_io};
  end

  always @(*) begin
    rd = 32'd0;
    if (re) begin
      case (a[3:0])
        4'h0: rd = {29'd0, fault, valid, busy};
        4'h4: rd = measurement;
        default: rd = 32'd0;
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      timer <= 32'd0;
      bits <= 40'd0;
      bit_count <= 6'd0;
      sample_bit <= 1'b0;
      busy <= 1'b0;
      valid <= 1'b0;
      fault <= 1'b0;
      drive_low <= 1'b0;
      measurement <= 32'd0;
    end else begin
      if (we && a[3:0] == 4'h0 && wd[0] && !busy) begin
        state <= START_LOW;
        timer <= 32'd0;
        bits <= 40'd0;
        bit_count <= 6'd0;
        busy <= 1'b1;
        valid <= 1'b0;
        fault <= 1'b0;
        drive_low <= 1'b1;
      end else begin
        case (state)
          IDLE: begin drive_low <= 1'b0; end
          START_LOW: begin
            if (timer >= START_CYCLES - 1) begin
              timer <= 0; drive_low <= 1'b0; state <= RELEASE_WAIT;
            end else timer <= timer + 1'b1;
          end
          RELEASE_WAIT: begin
            if (timer >= RELEASE_CYCLES - 1) begin
              timer <= 0; state <= RESP_LOW;
            end else timer <= timer + 1'b1;
          end
          RESP_LOW: begin
            if (!sync_line[2]) begin timer <= 0; state <= RESP_HIGH; end
            else if (timer >= TIMEOUT_CYCLES - 1) begin state <= FAILED; timer <= 0; end
            else timer <= timer + 1'b1;
          end
          RESP_HIGH: begin
            if (sync_line[2]) begin timer <= 0; state <= RESP_END; end
            else if (timer >= TIMEOUT_CYCLES - 1) begin state <= FAILED; timer <= 0; end
            else timer <= timer + 1'b1;
          end
          RESP_END: begin
            if (!sync_line[2]) begin timer <= 0; state <= BIT_LOW; end
            else if (timer >= TIMEOUT_CYCLES - 1) begin state <= FAILED; timer <= 0; end
            else timer <= timer + 1'b1;
          end
          BIT_LOW: begin
            if (sync_line[2]) begin timer <= 0; state <= BIT_SAMPLE; end
            else if (timer >= TIMEOUT_CYCLES - 1) begin state <= FAILED; timer <= 0; end
            else timer <= timer + 1'b1;
          end
          BIT_SAMPLE: begin
            if (timer >= SAMPLE_CYCLES - 1) begin
              sample_bit <= sync_line[2];
              timer <= 0;
              state <= BIT_END;
            end else timer <= timer + 1'b1;
          end
          BIT_END: begin
            if (!sync_line[2]) begin
              bits <= {bits[38:0], sample_bit};
              timer <= 0;
              if (bit_count == 6'd39) begin
                if (checksum == completed_bits[7:0]) begin
                  measurement <= {16'd0, completed_bits[39:32], completed_bits[23:16]};
                  valid <= 1'b1;
                  state <= FINISH;
                end else state <= FAILED;
              end else begin
                bit_count <= bit_count + 1'b1;
                state <= BIT_LOW;
              end
            end else if (timer >= TIMEOUT_CYCLES - 1) begin state <= FAILED; timer <= 0; end
            else timer <= timer + 1'b1;
          end
          FINISH: begin busy <= 1'b0; drive_low <= 1'b0; state <= IDLE; end
          FAILED: begin busy <= 1'b0; valid <= 1'b0; fault <= 1'b1; drive_low <= 1'b0; state <= IDLE; end
          default: begin state <= IDLE; drive_low <= 1'b0; busy <= 1'b0; end
        endcase
      end
    end
  end
endmodule
