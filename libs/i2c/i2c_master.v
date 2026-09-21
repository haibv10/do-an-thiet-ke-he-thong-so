// One I2C frame in either direction: optional START, eight data bits MSB
// first, one acknowledge bit, then an optional STOP. Frames without STOP chain
// into the next one, and a chained frame that asserts start_frame emits the
// repeated START a register read needs.
//
// On a write the slave drives the acknowledge bit and it appears on ack. On a
// read the master drives it from ack_out: a slave goes on transmitting until
// it is refused, so the last byte of a read has to be answered with a not
// acknowledge.
module i2c_master(
    input       clk,
    input       tick,
    input       rst_n,
    input       en,
    input       rw,             // 0 writes data, 1 reads into data_out
    input       start_frame,
    input       stop_frame,
    input       ack_out,        // read frames only: 0 acknowledges, 1 refuses
    input [7:0] data,
    inout       sda,
    inout       scl,
    output      done,
    output      busy,
    output reg  [7:0] data_out,
    output reg  ack,            // write frames only: the slave acknowledged
    output reg  sda_en
);

    // Every state is held for DELAY ticks of the 1 MHz enable, so SCL runs at
    // 50 kHz. That is inside standard mode and leaves a slave plenty of setup
    // time without needing a faster clock domain.
    localparam  DELAY       = 10;
    reg [20:0]  cnt;
    reg         cnt_clr;

    // Data bits are driven or sampled while SCL is low and high respectively,
    // so each bit costs two states.
    localparam  WaitEn      = 0,
                PreStart    = 1,
                StartSetup  = 15,
                Start       = 2,
                AfterStart  = 3,
                PreData     = 4,
                DataLow     = 5,
                DataHigh    = 6,
                DataDone    = 7,
                AckSetup    = 8,
                AckHigh     = 9,
                AckLow      = 10,
                AckDone     = 11,
                PreStop     = 12,
                Stop        = 13,
                Done        = 14;

    reg [3:0]   state, next_state;
    reg [3:0]   bit_cnt;
    reg         sda_out;
    reg         scl_drive_low;
    reg         rw_latched;
    wire        sda_in;
    reg         sda_meta, sda_sync;

    // Open drain: the master only ever pulls a line down and lets the external
    // pull-up provide the high level, so a slave stretching SCL or acking on SDA
    // never fights a driver.
    assign sda = sda_en ? (~sda_out ? 1'b0 : 1'bz) : 1'bz;
    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda_in = sda;

    // The slave releases or holds sda on its own timing, so every bit read off
    // the bus is resynchronised first. Free running on clk, not on tick,
    // because metastability has to settle in clock cycles. Two cycles cost 74 ns
    // against a 10 us state, so a sample still lands well inside its state.
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sda_meta <= 1'b1;
            sda_sync <= 1'b1;
        end else begin
            sda_meta <= sda_in;
            sda_sync <= sda_meta;
        end
    end

    // Latched at the start of the frame so that changing rw mid-transfer cannot
    // turn the data phase around while it is running.
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            rw_latched <= 1'b0;
        else if (tick && state == WaitEn && en)
            rw_latched <= rw;
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
                WaitEn:     next_state = en ? (start_frame ? PreStart : PreData) : WaitEn;
                PreStart:   next_state = (cnt == DELAY) ? StartSetup : PreStart;
                StartSetup: next_state = (cnt == DELAY) ? Start : StartSetup;
                Start:      next_state = (cnt == DELAY) ? AfterStart : Start;
                AfterStart: next_state = (cnt == DELAY) ? DataLow : AfterStart;
                PreData:    next_state = (cnt == DELAY) ? DataLow : PreData;
                DataLow:    next_state = (cnt == DELAY) ? DataHigh : DataLow;
                DataHigh:   next_state = (cnt == DELAY && bit_cnt == 4'd8) ? DataDone : ((cnt == DELAY) ? DataLow : DataHigh);
                DataDone:   next_state = (cnt == DELAY) ? AckSetup : DataDone;
                AckSetup:   next_state = (cnt == DELAY) ? AckHigh : AckSetup;
                AckHigh:    next_state = (cnt == DELAY) ? AckLow : AckHigh;
                AckLow:     next_state = (cnt == DELAY) ? AckDone : AckLow;
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
                // Releasing sda and scl together would raise sda while scl is
                // high, which is a stop condition. A chained frame reaches
                // here with sda held low, so the two moves are separated:
                // sda goes high under a low scl, then scl is released.
                PreStart: begin
                    ack     <= 1'b0;
                    sda_en  <= 1'b1;
                    sda_out <= 1'b1;
                    scl_drive_low <= 1'b1;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                StartSetup: begin
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
                PreData: begin
                    ack     <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                DataLow: begin
                    scl_drive_low <= 1'b1;
                    // On a read the slave owns sda for the whole data phase.
                    sda_en  <= ~rw_latched;
                    sda_out <= rw_latched ? 1'b1 : (data[7-(bit_cnt-1)] ? 1'b1 : 1'b0); // MSB first, as I2C requires
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                DataHigh: begin
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                DataDone: begin
                    scl_drive_low <= 1'b1;
                    // Write: hand sda to the slave so it can acknowledge.
                    // Read: take sda back, because the acknowledge is ours.
                    sda_en  <= rw_latched;
                    sda_out <= ack_out ? 1'b1 : 1'b0;               // high refuses, low acknowledges
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                AckSetup: begin
                    cnt_clr <= (cnt == DELAY) ? 1'b1 : 1'b0;
                end
                AckHigh: begin
                    scl_drive_low <= 1'b0;
                    if (!rw_latched)
                        ack <= (sda_sync == 1'b0);
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                AckLow: begin
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
                DataLow:    bit_cnt <= (cnt == 1'b0) ? bit_cnt + 1'b1 : bit_cnt;
                WaitEn:     bit_cnt <= 4'd0;
                Done:       bit_cnt <= 4'd0;
                default:    bit_cnt <= bit_cnt;
            endcase
        end
    end

    // Sampled at the midpoint of the scl high time, where the slave holds the
    // bit stable, rather than at an edge where it is free to move it.
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'd0;
        else if (tick && rw_latched && state == DataHigh && cnt == DELAY/2)
            data_out <= {data_out[6:0], sda_sync};
    end

    assign done = (state == Done);

    // A caller that only watches done cannot tell a frame that has not begun
    // from one that has already finished, since both sit outside the frame.
    assign busy = (state != WaitEn);

endmodule
