// Software-visible face of the I2C master. One store launches one frame,
// carrying the byte and the four flags that shape it, so a transaction is a
// sequence of stores rather than a mode the peripheral has to remember.
//
// Framing stays in software because a register read is device-specific: which
// register pointer to set, how many bytes follow and where the read turns
// around are all properties of the slave, not of the bus.
module i2c_mmio (
  input  wire        clk,
  input  wire        tick,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output reg  [31:0] rd,
  inout  wire        sda,
  inout  wire        scl
);

  wire       frame_done;
  wire       frame_busy;
  wire       frame_ack;
  wire [7:0] frame_data;
  wire       sda_en;

  reg        en;
  reg        busy;
  reg  [7:0] tx_data;
  reg        start_frame;
  reg        stop_frame;
  reg        rw;
  reg        ack_out;

  wire launch = we && (a[7:0] == 8'h00) && !busy;

  i2c_master master_inst (
    .clk(clk),
    .tick(tick),
    .rst_n(rst_n),
    .en(en),
    .rw(rw),
    .start_frame(start_frame),
    .stop_frame(stop_frame),
    .ack_out(ack_out),
    .data(tx_data),
    .sda(sda),
    .scl(scl),
    .done(frame_done),
    .busy(frame_busy),
    .data_out(frame_data),
    .ack(frame_ack),
    .sda_en(sda_en)
  );

  // en is a request, not a duration: it is dropped once the master has left
  // its idle state, so the frame cannot restart when the master returns there.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      en          <= 1'b0;
      busy        <= 1'b0;
      tx_data     <= 8'd0;
      start_frame <= 1'b0;
      stop_frame  <= 1'b0;
      rw          <= 1'b0;
      ack_out     <= 1'b0;
    end else if (launch) begin
      tx_data     <= wd[7:0];
      start_frame <= wd[8];
      stop_frame  <= wd[9];
      rw          <= wd[10];
      ack_out     <= wd[11];
      en          <= 1'b1;
      busy        <= 1'b1;
    end else if (en && frame_busy) begin
      en          <= 1'b0;
    end else if (busy && !en && !frame_busy) begin
      busy        <= 1'b0;
    end
  end

  // The master holds the received byte and the acknowledge until the next
  // frame disturbs them, so both are read straight out of it while busy is 0.
  always @(*) begin
    rd = 32'd0;
    case (a[7:0])
      8'h04: begin
        rd[0] = busy;
        rd[1] = frame_ack;
      end
      8'h08: rd = {24'd0, frame_data};
      default: ;
    endcase
  end

endmodule
