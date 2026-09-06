module gpio (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output wire [31:0] rd,
  output reg         led,
  input  wire        btn_in
);

  // Chỉ soi 8 bit cuối (Offset) thay vì soi toàn bộ địa chỉ
  // a[7:0] == 8'h00 -> Tương ứng địa chỉ 0x40000000 (LED)
  // a[7:0] == 8'h04 -> Tương ứng địa chỉ 0x40000004 (Nút bấm)

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led <= 1'b0;
    end else if (we && (a[7:0] == 8'h00)) begin // <-- Đã sửa
      led <= wd[0];
    end
  end

  assign rd = (a[7:0] == 8'h00) ? {31'd0, led} :  // <-- Đã sửa
        (a[7:0] == 8'h04) ? {31'd0, btn_in} : 32'd0; // <-- Đã sửa

endmodule
