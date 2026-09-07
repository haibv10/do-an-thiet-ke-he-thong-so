module regfile (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,     // Write Enable: Tín hiệu cho phép ghi (1 = cho phép, 0 = khóa)
  input  wire [4:0]  rs1,    // Địa chỉ thanh ghi nguồn 1 (5 bit vì 2^5 = 32)
  input  wire [4:0]  rs2,    // Địa chỉ thanh ghi nguồn 2
  input  wire [4:0]  rd,     // Địa chỉ thanh ghi đích (nơi ghi kết quả vào)
  input  wire [31:0] wd,     // Write Data: Dữ liệu cần ghi
  output wire [31:0] rd1,    // Read Data 1: Dữ liệu xuất ra từ ngăn rs1
  output wire [31:0] rd2     // Read Data 2: Dữ liệu xuất ra từ ngăn rs2
);

  // Tạo 31 ngăn chứa (từ x1 đến x31). Ngăn x0 không cần tạo vì nó luôn bằng 0.
  reg [31:0] x [31:1];
  integer i;

  // Quá trình GHI (Chỉ xảy ra khi có sườn lên xung Clock)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Khi Reset, dọn dẹp toàn bộ 31 ngăn chứa về số 0
      for (i = 1; i < 32; i = i + 1) begin
        x[i] <= 32'd0;
      end
    end else if (we && (rd != 5'd0)) begin
      // Chỉ cho phép ghi nếu cờ 'we' bật VÀ địa chỉ đích không phải là x0
      x[rd] <= wd;
    end
  end

  // Quá trình ĐỌC (Đọc ngay lập tức như 1 sợi dây, không cần chờ nhịp Clock)
  assign rd1 = (rs1 == 5'd0) ? 32'd0 : x[rs1];
  assign rd2 = (rs2 == 5'd0) ? 32'd0 : x[rs2];

endmodule
