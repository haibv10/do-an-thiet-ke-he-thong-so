// One HD44780 byte over a PCF8574 backpack.
//
// The backpack wires the expander to the display as
//   P7..P4 = DB7..DB4, P3 = backlight, P2 = EN, P1 = RW, P0 = RS
// so the bus is 4 bits wide and the display latches a nibble on the falling
// edge of EN. That costs five I2C frames per byte: the slave address, then the
// high nibble with EN high and again with EN low, then the same for the low
// nibble. Only the first frame opens with a START and only the last closes with
// a STOP, so all five stay inside one bus session.
module i2c_pcf8574_lcd_write(
    input       clk,
    input       tick,
    input       rst_n,
    input [7:0] data,
    input       cmd_data,                   // 0 = command, 1 = character data
    input       ena,
    input [6:0] i2c_addr,                   // strap pins select it: 0x20-0x27 on a PCF8574, 0x38-0x3F on a PCF8574A
    inout       sda,
    output      scl,
    output      done,
    output      ack,
    output      sda_en
);

    // The HD44780 needs roughly 40 us to retire most commands and gives no
    // status over this one-way 4-bit link, so the delay is open loop.
    localparam  DELAY               = 50;
    reg [20:0]  cnt;
    reg         cnt_clr;

    localparam  WaitEn              = 0,
                Write_Addr          = 1,
                Wait_AddrDone       = 2,
                Write_HighNibble1   = 3,
                Wait_High1Done      = 4,
                Delay_CMD1          = 5,
                Write_HighNibble2   = 6,
                Wait_High2Done      = 7,
                Write_LowNibble1    = 8,
                Wait_Low1Done       = 9,
                Delay_CMD2          = 10,
                Write_LowNibble2    = 11,
                Wait_Low2Done       = 12,
                Done                = 13;

    reg [3:0]   state, next_state;
    reg         en_write;
    wire        en_i2cwrite = en_write;
    wire        i2c_done;
    wire        i2c_ack;
    reg         ack_result;
    reg [7:0]   i2c_data;

    reg         start_frame;
    reg         stop_frame;

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
                WaitEn:             next_state = ena ? Write_Addr : WaitEn;
                Write_Addr:         next_state = Wait_AddrDone;
                Wait_AddrDone:      next_state = i2c_done ? Write_HighNibble1 : Wait_AddrDone;
                Write_HighNibble1:  next_state = Wait_High1Done;
                Wait_High1Done:     next_state = i2c_done ? Delay_CMD1 : Wait_High1Done;
                Delay_CMD1:         next_state = (cnt == DELAY) ? Write_HighNibble2 : Delay_CMD1;
                Write_HighNibble2:  next_state = Wait_High2Done;
                Wait_High2Done:     next_state = i2c_done ? Write_LowNibble1 : Wait_High2Done;
                Write_LowNibble1:   next_state = Wait_Low1Done;
                Wait_Low1Done:      next_state = i2c_done ? Delay_CMD2 : Wait_Low1Done;
                Delay_CMD2:         next_state = (cnt == DELAY) ? Write_LowNibble2 : Delay_CMD2;
                Write_LowNibble2:   next_state = Wait_Low2Done;
                Wait_Low2Done:      next_state = i2c_done ? Done : Wait_Low2Done;
                Done:               next_state = WaitEn;
                default:            next_state = WaitEn;
            endcase
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            i2c_data <= 8'd0;
            en_write <= 1'b0;
            cnt_clr  <= 1'b1;
            ack_result <= 1'b0;
        end else if (tick) begin
            case (state)
                WaitEn: begin
                    i2c_data    <= 8'd0;
                    en_write    <= 1'b0;
                    cnt_clr     <= 1'b1;
                end
                Write_Addr: begin
                    start_frame <= 1'b1;
                    stop_frame  <= 1'b0;
                    i2c_data    <= {i2c_addr, 1'b0};    // bit 0 low marks the transfer as a write
                    en_write    <= 1'b1;
                end
                Wait_AddrDone: begin
                    en_write    <= 1'b0;
                end
                Write_HighNibble1: begin
                    start_frame <= 1'b0;
                    stop_frame  <= 1'b0;
                    i2c_data    <= (data & 8'hF0) | 8'h0C | cmd_data;   // high nibble, EN high
                    en_write    <= 1'b1;
                end
                Wait_High1Done: begin
                    en_write    <= 1'b0;
                end
                Delay_CMD1: begin
                    cnt_clr     <= 1'b0;
                end
                Write_HighNibble2: begin
                    start_frame <= 1'b0;
                    stop_frame  <= 1'b0;
                    i2c_data    <= ((data & 8'hF0) | 8'h0C | cmd_data) & 8'hFB; // EN low latches it
                    en_write    <= 1'b1;
                    cnt_clr     <= 1'b1;
                end
                Wait_High2Done: begin
                    en_write    <= 1'b0;
                end
                Write_LowNibble1: begin
                    start_frame <= 1'b0;
                    stop_frame  <= 1'b0;
                    i2c_data    <= ((data & 8'h0F) << 4) | 8'h0C | cmd_data;    // low nibble, EN high
                    en_write    <= 1'b1;
                end
                Wait_Low1Done: begin
                    en_write    <= 1'b0;
                end
                Delay_CMD2: begin
                    cnt_clr     <= 1'b0;
                end
                Write_LowNibble2: begin
                    start_frame <= 1'b0;
                    stop_frame  <= 1'b1;                // last frame of the byte, so close the session
                    i2c_data    <= (((data & 8'h0F) << 4) | 8'h0C | cmd_data) & 8'hFB; // EN low latches it
                    en_write    <= 1'b1;
                    cnt_clr     <= 1'b1;
                end
                Wait_Low2Done: begin
                    en_write    <= 1'b0;
                    ack_result <= i2c_ack;
                end
            endcase
        end
    end

    assign done = (state == Done);
    assign ack = ack_result;

    i2c_write_frame i2c_writframe_inst(
        .clk        (clk),
        .tick       (tick),
        .rst_n      (rst_n),
        .en_write   (en_i2cwrite),
        .start_frame(start_frame),
        .stop_frame (stop_frame),
        .data       (i2c_data),
        .sda        (sda),
        .scl        (scl),
        .done       (i2c_done),
        .ack        (i2c_ack),
        .sda_en     (sda_en)
    );

endmodule
