module forwarding_unit (
  // --- Lắng nghe Trạm 3 (EX) đang cần gì ---
  input  wire [4:0] id_ex_rs1,
  input  wire [4:0] id_ex_rs2,

  // --- Lắng nghe Trạm 4 (MEM) sắp ghi gì ---
  input  wire       ex_mem_RegWrite,
  input  wire [4:0] ex_mem_rd,

  // --- Lắng nghe Trạm 5 (WB) sắp ghi gì ---
  input  wire       mem_wb_RegWrite,
  input  wire [4:0] mem_wb_rd,

  // --- Quyết định bẻ ghi-đông (MUX) ---
  output reg  [1:0] forward_a, // Điều khiển ngõ vào A của ALU
  output reg  [1:0] forward_b  // Điều khiển ngõ vào B của ALU
);

  always @(*) begin
    // -------------------------------------------------------------
    // 1. Kiểm tra ngõ vào A (rs1)
    // -------------------------------------------------------------
    // Ưu tiên 1: Lấy từ trạm MEM (vì nó mới nhất)
    if (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      forward_a = 2'b10;
    end
    // Ưu tiên 2: Lấy từ trạm WB (cũ hơn một chút)
    else if (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      forward_a = 2'b01;
    end
    // Không trùng gì cả: Lấy từ dây bình thường (RegFile)
    else begin
      forward_a = 2'b00;
    end

    // -------------------------------------------------------------
    // 2. Kiểm tra ngõ vào B (rs2)
    // -------------------------------------------------------------
    if (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
      forward_b = 2'b10;
    end
    else if (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
      forward_b = 2'b01;
    end
    else begin
      forward_b = 2'b00;
    end
  end

endmodule
