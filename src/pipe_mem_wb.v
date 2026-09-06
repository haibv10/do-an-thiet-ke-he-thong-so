module pipe_mem_wb (
  input  wire        clk,
  input  wire        rst_n,

  // --- CÁC TÍN HIỆU ĐIỀU KHIỂN ---
  input  wire        mem_RegWrite,
  input  wire        mem_MemtoReg,

  // --- DỮ LIỆU ĐẦU VÀO (Từ trạm MEM) ---
  input  wire [31:0] mem_read_data,   // Hàng vừa lấy ra từ tủ RAM (hoặc GPIO)
  input  wire [31:0] mem_alu_result,  // Kết quả tính toán (truyền xuyên qua)
  input  wire [4:0]  mem_rd_idx,      // Đích đến

  // --- DỮ LIỆU ĐẦU RA (Tới trạm WB) ---
  output reg         wb_RegWrite,
  output reg         wb_MemtoReg,

  output reg [31:0]  wb_read_data,
  output reg [31:0]  wb_alu_result,
  output reg [4:0]   wb_rd_idx
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {wb_RegWrite, wb_MemtoReg} <= 2'b0;
      {wb_read_data, wb_alu_result} <= 64'b0;
      wb_rd_idx <= 5'b0;
    end else begin
      wb_RegWrite   <= mem_RegWrite;
      wb_MemtoReg   <= mem_MemtoReg;
      wb_read_data  <= mem_read_data;
      wb_alu_result <= mem_alu_result;
      wb_rd_idx     <= mem_rd_idx;
    end
  end
endmodule
