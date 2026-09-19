// Covers dependencies one and two instructions apart. Distance three is caught
// by the write-first bypass inside the register file.
module forwarding_unit (
  input  wire [4:0] id_ex_rs1,
  input  wire [4:0] id_ex_rs2,

  input  wire       ex_mem_RegWrite,
  input  wire [4:0] ex_mem_rd,

  input  wire       mem_wb_RegWrite,
  input  wire [4:0] mem_wb_rd,

  output reg  [1:0] forward_a,
  output reg  [1:0] forward_b
);

  always @(*) begin
    // MEM is checked before WB: when both stages target the same register, the
    // younger instruction in MEM holds the value that must win.
    if (ex_mem_RegWrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      forward_a = 2'b10;
    end
    else if (mem_wb_RegWrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      forward_a = 2'b01;
    end
    else begin
      forward_a = 2'b00;
    end

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
