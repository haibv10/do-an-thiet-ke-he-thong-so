module i2c_mmio #(
  parameter [6:0] pcf8574_addr = 7'h27
)(
  input wire clk, input wire tick, input wire rst_n, input wire we,
  input wire [31:0] a, input wire [31:0] wd, output reg [31:0] rd,
  inout wire sda, output wire scl
);
  reg busy, done_seen, cmd_data, ack_result;
  reg [7:0] data;
  reg [6:0] i2c_addr;
  wire done, sda_en, ack;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin busy<=0; done_seen<=0; cmd_data<=0; data<=0; i2c_addr<=pcf8574_addr; ack_result<=0; end
    else begin
      if (busy && done && !done_seen) begin done_seen <= 1; ack_result <= ack; end
      else if (busy && done_seen && !done) begin busy <= 0; done_seen <= 0; end
      else if (we && a[3:2] == 2'b10 && !busy) i2c_addr <= wd[6:0];
      else if (we && a[3:2] == 0 && !busy) begin
        data <= wd[7:0]; cmd_data <= wd[8]; busy <= 1; done_seen <= 0;
      end
    end
  end

  always @(*) rd = (a[3:2] == 2'b01) ? {30'd0, ack_result, busy} : 32'd0;

  lcd_write_cmd_data writer (
    .clk(clk), .tick(tick), .rst_n(rst_n), .data(data), .cmd_data(cmd_data),
    .ena(busy && !done_seen), .i2c_addr(i2c_addr), .sda(sda), .scl(scl),
    .done(done), .ack(ack), .sda_en(sda_en)
  );
endmodule
