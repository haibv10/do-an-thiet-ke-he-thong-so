module pipe_id_ex (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        flush,

  input  wire        id_RegWrite,
  input  wire        id_MemtoReg,
  input  wire        id_MemWrite,
  input  wire        id_MemRead,
  input  wire        id_Branch,
  input  wire [1:0]  id_Jump,
  input  wire        id_ALUSrc,
  input  wire [3:0]  id_alu_ctrl,
  input  wire [2:0]  id_funct3,

  input  wire [31:0] id_pc,
  input  wire [31:0] id_rd1,
  input  wire [31:0] id_rd2,
  input  wire [31:0] id_imm,
  input  wire [4:0]  id_rs1_idx,
  input  wire [4:0]  id_rs2_idx,
  input  wire [4:0]  id_rd_idx,

  output reg         ex_RegWrite,
  output reg         ex_MemtoReg,
  output reg         ex_MemWrite,
  output reg         ex_MemRead,
  output reg         ex_Branch,
  output reg  [1:0]  ex_Jump,
  output reg         ex_ALUSrc,
  output reg  [3:0]  ex_alu_ctrl,
  output reg  [2:0]  ex_funct3,

  output reg  [31:0] ex_pc,
  output reg  [31:0] ex_rd1,
  output reg  [31:0] ex_rd2,
  output reg  [31:0] ex_imm,
  output reg  [4:0]  ex_rs1_idx,
  output reg  [4:0]  ex_rs2_idx,
  output reg  [4:0]  ex_rd_idx
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      {ex_RegWrite, ex_MemtoReg, ex_MemWrite, ex_MemRead, ex_Branch, ex_ALUSrc} <= 6'b0;
      ex_Jump <= 2'b0;
      ex_alu_ctrl <= 4'b0;
      ex_funct3   <= 3'b0;
      {ex_pc, ex_rd1, ex_rd2, ex_imm} <= 128'b0;
      {ex_rs1_idx, ex_rs2_idx, ex_rd_idx} <= 15'b0;
    end else begin
      ex_RegWrite <= id_RegWrite;
      ex_MemtoReg <= id_MemtoReg;
      ex_MemWrite <= id_MemWrite;
      ex_MemRead  <= id_MemRead;
      ex_Branch   <= id_Branch;
      ex_Jump     <= id_Jump;
      ex_ALUSrc   <= id_ALUSrc;
      ex_alu_ctrl <= id_alu_ctrl;
      ex_funct3   <= id_funct3;
      ex_pc       <= id_pc;
      ex_rd1      <= id_rd1;
      ex_rd2      <= id_rd2;
      ex_imm      <= id_imm;
      ex_rs1_idx  <= id_rs1_idx;
      ex_rs2_idx  <= id_rs2_idx;
      ex_rd_idx   <= id_rd_idx;
    end
  end
endmodule
