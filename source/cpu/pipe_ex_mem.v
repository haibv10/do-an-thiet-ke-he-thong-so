module pipe_ex_mem (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        ex_RegWrite,
  input  wire        ex_MemtoReg,
  input  wire        ex_MemWrite,
  input  wire        ex_MemRead,
  input  wire [31:0] ex_alu_result,
  input  wire [31:0] ex_rd2,
  input  wire [4:0]  ex_rd_idx,
  input  wire [2:0]  ex_funct3,

  output reg         mem_RegWrite,
  output reg         mem_MemtoReg,
  output reg         mem_MemWrite,
  output reg         mem_MemRead,
  output reg  [31:0] mem_alu_result,
  output reg  [31:0] mem_rd2,
  output reg  [4:0]  mem_rd_idx,
  output reg  [2:0]  mem_funct3
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {mem_RegWrite, mem_MemtoReg, mem_MemWrite, mem_MemRead} <= 4'b0;
      {mem_alu_result, mem_rd2} <= 64'b0;
      mem_rd_idx <= 5'b0;
      mem_funct3 <= 3'b0;
    end else begin
      mem_RegWrite      <= ex_RegWrite;
      mem_MemtoReg      <= ex_MemtoReg;
      mem_MemWrite      <= ex_MemWrite;
      mem_MemRead       <= ex_MemRead;
      mem_alu_result    <= ex_alu_result;
      mem_rd2           <= ex_rd2;
      mem_rd_idx        <= ex_rd_idx;
      mem_funct3        <= ex_funct3;
    end
  end
endmodule
