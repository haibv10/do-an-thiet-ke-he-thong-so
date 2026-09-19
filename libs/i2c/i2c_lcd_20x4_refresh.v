module i2c_lcd_20x4_refresh(
  input clk_1MHz, input rst_n, input ena, input done_write,
  input [159:0] row1, input [159:0] row2, input [159:0] row3, input [159:0] row4,
  output reg [7:0] data, output reg cmd_data, output reg ena_write
);
  localparam WaitEn=0, Write=1, WaitWrite=3, WaitDelay=4, Done=5;
  reg [2:0] state, next_state;
  reg [20:0] cnt;
  reg cnt_clr;
  reg [6:0] ptr;
  wire [7:0] lcd_bytes [0:88];

  assign lcd_bytes[0]=8'h02; assign lcd_bytes[1]=8'h28;
  assign lcd_bytes[2]=8'h0C; assign lcd_bytes[3]=8'h06;
  assign lcd_bytes[4]=8'h01; assign lcd_bytes[5]=8'h80;
  assign lcd_bytes[26]=8'hC0; assign lcd_bytes[47]=8'h94; assign lcd_bytes[68]=8'hD4;
  generate
    genvar i;
    for (i=0; i<20; i=i+1) begin: rows
      assign lcd_bytes[6+i]  = row1[159-i*8 -: 8];
      assign lcd_bytes[27+i] = row2[159-i*8 -: 8];
      assign lcd_bytes[48+i] = row3[159-i*8 -: 8];
      assign lcd_bytes[69+i] = row4[159-i*8 -: 8];
    end
  endgenerate

  always @(posedge clk_1MHz or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else if (cnt_clr) cnt <= 0;
    else cnt <= cnt + 1'b1;
  end
  always @(posedge clk_1MHz or negedge rst_n) begin
    if (!rst_n) state <= WaitEn;
    else state <= next_state;
  end
  always @(*) begin
    case (state)
      WaitEn: next_state = ena ? Write : WaitEn;
      Write: next_state = WaitWrite;
      WaitWrite: next_state = done_write ? WaitDelay : WaitWrite;
      WaitDelay: next_state = (ptr == 7'd89) ? Done : (cnt == 21'd50 ? Write : WaitDelay);
      Done: next_state = (cnt == 21'd50_000) ? Write : Done;
      default: next_state = WaitEn;
    endcase
  end
  always @(posedge clk_1MHz or negedge rst_n) begin
    if (!rst_n) begin cnt_clr<=1'b1; ena_write<=1'b0; data<=0; cmd_data<=1'b0; end
    else case (state)
      WaitEn: begin cnt_clr<=1'b1; ena_write<=1'b0; end
      Write: begin
        cnt_clr<=1'b1;
        data<=lcd_bytes[ptr];
        cmd_data<=(ptr <= 7'd5 || ptr == 7'd26 || ptr == 7'd47 || ptr == 7'd68) ? 1'b0 : 1'b1;
        ena_write<=1'b1;
      end
      WaitWrite: ena_write<=1'b0;
      WaitDelay: cnt_clr<=1'b0;
      // Done must let the counter reach 50 ms before returning to Write to refresh the frame
      Done: begin cnt_clr<=1'b0; ena_write<=1'b0; end
      default: begin cnt_clr<=1'b1; ena_write<=1'b0; end
    endcase
  end
  always @(posedge clk_1MHz or negedge rst_n) begin
    if (!rst_n) ptr <= 0;
    else if (state == Write) ptr <= ptr + 1'b1;
    else if (state == Done && cnt == 21'd50_000) ptr <= 7'd5;
  end
endmodule
