module i2c_master(
    input       clk,
    input       tick,
    input       rst_n,
    input       en,
    input       rw,
    input       start_frame,
    input       stop_frame,
    input       ack_out,
    input [7:0] data,
    inout       sda,
    inout       scl,
    output      done,
    output      busy,
    output reg  [7:0] data_out,
    output reg  ack,
    output reg  sda_en
);

    localparam  DELAY       = 10;
    reg [20:0]  cnt;
    reg         cnt_clr;

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

    assign sda = sda_en ? (~sda_out ? 1'b0 : 1'bz) : 1'bz;
    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda_in = sda;

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
            sda_out <= 1'b1;
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
                    sda_out <= 1'b0;
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

                    sda_en  <= ~rw_latched;
                    sda_out <= rw_latched ? 1'b1 : (data[7-(bit_cnt-1)] ? 1'b1 : 1'b0);
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                DataHigh: begin
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                DataDone: begin
                    scl_drive_low <= 1'b1;

                    sda_en  <= rw_latched;
                    sda_out <= ack_out ? 1'b1 : 1'b0;
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
                    sda_out <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                PreStop: begin
                    scl_drive_low <= 1'b0;
                    cnt_clr <= (cnt == DELAY-1) ? 1'b1 : 1'b0;
                end
                Stop: begin
                    sda_out <= 1'b1;
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

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'd0;
        else if (tick && rw_latched && state == DataHigh && cnt == DELAY/2)
            data_out <= {data_out[6:0], sda_sync};
    end

    assign done = (state == Done);

    assign busy = (state != WaitEn);

endmodule
