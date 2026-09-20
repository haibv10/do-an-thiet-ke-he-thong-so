module pipe_hazard (
  input  wire [4:0] if_id_rs1,
  input  wire [4:0] if_id_rs2,
  input  wire       if_id_UsesRs1,
  input  wire       if_id_UsesRs2,
  input  wire       id_ex_MemRead,
  input  wire [4:0] id_ex_rd,
  output reg        stall
);
  always @(*) begin
    if (id_ex_MemRead && (id_ex_rd != 5'd0) &&
     ((if_id_UsesRs1 && (id_ex_rd == if_id_rs1)) ||
      (if_id_UsesRs2 && (id_ex_rd == if_id_rs2)))) begin
      stall = 1'b1;
    end else begin
      stall = 1'b0;
    end
  end
endmodule
