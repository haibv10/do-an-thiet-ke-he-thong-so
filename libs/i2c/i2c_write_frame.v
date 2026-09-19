// One I2C write frame: optional START, eight data bits MSB first, the slave's
// ACK bit, then an optional STOP. Frames without STOP chain into the next one,
// which is how a multi-byte PCF8574 transfer stays inside a single bus session.
module i2c_write_frame(
    input       clk,
    input       tick,
    input       rst_n,
    input       en_write,
    input       start_frame,
    input       stop_frame,
    input [7:0] data,
    inout       sda,
    inout       scl,
    output      done,
    output reg  ack,
    output reg  sda_en
);

    // Every state is held for DELAY ticks of the 1 MHz enable, so SCL runs at
    // 50 kHz. That is inside standard mode and leaves the PCF8574 plenty of
    // setup time without needing a faster clock domain.
    localparam  DELAY       = 10;
    reg [20:0]  cnt;
    reg         cnt_clr;

    // Data bits are driven while SCL is low and latched by the slave on the
    // rising edge, so each bit costs two states.
    localparam  WaitEn      = 0,
                PreStart    = 1,
                Start       = 2,
                AfterStart  = 3,
                PreWrite    = 4,
                WriteLow    = 5,
                WriteHigh   = 6,
                WriteDone   = 7,
                WaitAck     = 8,
                Ack1        = 9,
                Ack2        = 10,
                AckDone     = 11,
                PreStop     = 12,
                Stop        = 13,
                Done        = 14;

    reg [3:0]   state, next_state;
    reg [3:0]   bit_cnt;
    reg         sda_out;
    reg         scl_drive_low;
    wire        sda_in;
    reg         sda_meta, sda_sync;

    // Open drain: the master only ever pulls a line down and lets the external
    // pull-up provide the high level, so a slave stretching SCL or acking on SDA
    // never fights a driver.
    assign sda = sda_en ? (~sda_out ? 1'b0 : 1'bz) : 1'bz;
    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda_in = sda;

    // The slave releases or holds sda on its own timing, so the ack bit is
    // resynchronised before it is sampled. Free running on clk, not on tick,
    // because metastability has to settle in clock cycles. Two cycles cost 74 ns
    // against a 10 us state, so the sample still lands well inside Ack1.
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sda_meta <= 1'b1;
            sda_sync <= 1'b1;
        end else begin
            sda_meta <= sda_in;
            sda_sync <= sda_meta;
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            cnt <= 21'd0;
        else if (tick) begin
            if (cnt_clr)
                cnt <= 21'd0;
            else
                cnt <= cnt + 1'b1;
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            state <= WaitEn;
        else if (tick)
            state <= next_state;
    end

    always @(*) begin
        next_state = WaitEn;
        if (!rst_n)
            next_state = WaitEn;
        else begin
            case (state)
                WaitEn:     next_state = en_write ? (start_frame ? PreStart : PreWrite) : WaitEn;
                PreStart:   next_state = (cnt == DELAY) ? Start : PreStart;
                Start:      next_state = (cnt == DELAY) ? AfterStart : Start;
                AfterStart: next_state = (cnt == DELAY) ? WriteLow : AfterStart;
                PreWrite:   next_state = (cnt == DELAY) ? WriteLow : PreWrite;
                WriteLow:   next_state = (cnt == DELAY) ? WriteHigh : WriteLow;
                WriteHigh:  next_state = (cnt == DELAY && bit_cnt == 4'd8) ? WriteDone : ((cnt == DELAY) ? WriteLow : WriteHigh);
                WriteDone:  next_state = (cnt == DELAY) ? WaitAck : WriteDone;
                WaitAck:    next_state = (cnt == DELAY) ? Ack1 : WaitAck;
                Ack1:       next_state = (cnt == DELAY) ? Ack2 : Ack1;
                Ack2:       next_state = (cnt == DELAY) ? AckDone : Ack2;
                AckDone:    next_state = (cnt == DELAY) ? (stop_frame ? PreStop : Done) : AckDone;
                PreStop:    next_state = (cnt == DELAY) ? Stop : PreStop;
                Stop:       next_state = (cnt == DELAY) ? Done : Stop;
                Done:       next_state = WaitEn;
                default:    next_state = WaitEn;
            endcase
        end
    end   


    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sda_en  <= 1'b1;
            sda_out <= 1'b1;                // an unreset driver would hold the bus low from power-up
            cnt_clr <= 1'b1;
            ack     <= 1'b0;
            scl_drive_low <= 1'b0;
        end else if (tick) begin
            case (state)
                WaitEn: begin
                    sda_en  <= 1'b1;
                    cnt_clr <= 1'b1;
                end
                PreStart: begin
                    ack     <= 1'b0;
                    sda_out <= 1'b1;
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                Start: begin
                    sda_out <= 1'b0;                                // sda falling while scl is high is the start condition
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                AfterStart: begin
                    scl_drive_low <= 1'b1;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                PreWrite: begin
                    ack     <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                WriteLow: begin
                    scl_drive_low <= 1'b1;
                    sda_out <= data[7-(bit_cnt-1)] ? 1'b1 : 1'b0;   // MSB first, as I2C requires
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                WriteHigh: begin
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                WriteDone: begin
                    scl_drive_low <= 1'b1;
                    sda_en  <= 1'b0;                                // hand sda to the slave for the ack bit
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                WaitAck: begin
                    cnt_clr <= (cnt == DELAY) ? 1'b1 : 1'b0;
                end
                Ack1: begin
                    scl_drive_low <= 1'b0;
                    ack     <= (sda_sync == 1'b0);
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                Ack2: begin
                    scl_drive_low <= 1'b1;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                AckDone: begin
                    sda_en  <= 1'b1;
                    sda_out <= 1'b0;                                // sda must already be low before scl rises, or there is no stop edge later
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                PreStop: begin
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end   
                Stop: begin
                    sda_out <= 1'b1;                                // sda rising while scl is high is the stop condition
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                Done: begin
                    cnt_clr <= 1'b1;
                end
            endcase
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 4'd0;
        else if (tick) begin
            case (state)
                WriteLow:   bit_cnt <= (cnt == 1'b0) ? bit_cnt + 1'b1 : bit_cnt;
                WaitEn:     bit_cnt <= 4'd0;
                Done:       bit_cnt <= 4'd0;
                default:    bit_cnt <= bit_cnt;
            endcase
        end
    end

    assign done = (state == Done);

endmodule
