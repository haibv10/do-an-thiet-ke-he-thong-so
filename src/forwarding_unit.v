module forwarding_unit (
  // --- What EX needs ---
  input  wire [4:0] id_ex_rs1,
  input  wire [4:0] id_ex_rs2,

  // --- What MEM is about to write ---
  input  wire       ex_mem_RegWrite,
  input  wire [4:0] ex_mem_rd,

  // --- What WB is about to write ---
  input  wire       mem_wb_RegWrite,
  input  wire [4:0] mem_wb_rd,

  // --- Mux selects ---
  output reg  [1:0] forward_a, // selects the ALU A input
  output reg  [1:0] forward_b  // selects the ALU B input
);

  always @(*) begin
    // -------------------------------------------------------------
    // 1. Input A (rs1)
    // -------------------------------------------------------------
    // Priority 1: take it from MEM, that value is the newest
    if (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      forward_a = 2'b10;
    end
    // Priority 2: take it from WB
    else if (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      forward_a = 2'b01;
    end
    // No match: use the register file output
    else begin
      forward_a = 2'b00;
    end

    // -------------------------------------------------------------
    // 2. Input B (rs2)
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
