// Fixed-latency ports: instruction/data reads settle before the next rising edge.
// The SoC supplies falling-edge ROM/RAM reads; there is no ready/wait handshake.
module cpu_top (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] instr_addr,
  input  wire [31:0] instr_data,
  output wire [31:0] data_addr,
  output wire [31:0] data_wdata,
  output wire [ 3:0] data_wstrb,
  output wire        data_re,
  input  wire [31:0] data_rdata
);
  wire stall;
  wire branch_taken;
  wire jump_taken;
  wire pc_change_taken = branch_taken | jump_taken;

  wire if_id_flush = pc_change_taken;
  wire id_ex_flush = pc_change_taken | stall;

  wire [31:0] if_pc, if_next_pc;
  wire [31:0] if_instr = instr_data;
  wire [31:0] ex_branch_target, jump_target;
  wire [31:0] mem_alu_result;
  core_pc pc_register (
    .clk    (clk),
    .rst_n  (rst_n),
    .stall  (stall),
    .pc_next(if_next_pc),
    .pc     (if_pc)
  );

  assign if_next_pc = (jump_taken)   ? jump_target :
            (branch_taken) ? ex_branch_target :
                    (if_pc + 32'd4);

  wire [31:0] id_pc, id_instr;
  pipe_if_id reg_if_id (
    .clk     (clk),
    .rst_n   (rst_n),
    .stall   (stall),
    .flush   (if_id_flush),
    .if_pc   (if_pc),
    .if_instr(if_instr),
    .id_pc   (id_pc),
    .id_instr(id_instr)
  );

  wire id_Branch, id_MemRead, id_MemtoReg, id_MemWrite, id_ALUSrc, id_ALUSrcA, id_RegWrite;
  wire id_UsesRs1, id_UsesRs2;
  wire       id_Fence;
  wire [1:0] id_Jump;
  wire [3:0] id_alu_ctrl;
  wire [31:0] id_imm, id_rd1, id_rd2;

  wire [4:0] id_rs1_idx = id_instr[19:15];
  wire [4:0] id_rs2_idx = id_instr[24:20];
  wire [4:0] id_rd_idx = id_instr[11:7];
  wire [2:0] id_funct3 = id_instr[14:12];

  wire       ex_MemRead;
  wire [4:0] ex_rd_idx;

  pipe_hazard hdu (
    .if_id_rs1    (id_rs1_idx),
    .if_id_rs2    (id_rs2_idx),
    .if_id_UsesRs1(id_UsesRs1),
    .if_id_UsesRs2(id_UsesRs2),
    .id_ex_MemRead(ex_MemRead),
    .id_ex_rd     (ex_rd_idx),
    .stall        (stall)
  );

  core_control ctrl (
    .opcode  (id_instr[6:0]),
    .funct3  (id_funct3),
    .funct7_5(id_instr[30]),
    .Branch  (id_Branch),
    .Jump    (id_Jump),
    .MemRead (id_MemRead),
    .MemtoReg(id_MemtoReg),
    .MemWrite(id_MemWrite),
    .ALUSrc  (id_ALUSrc),
    .ALUSrcA (id_ALUSrcA),
    .RegWrite(id_RegWrite),
    .UsesRs1 (id_UsesRs1),
    .UsesRs2 (id_UsesRs2),
    .Fence   (id_Fence),
    .alu_ctrl(id_alu_ctrl)
  );

  core_immediate ig (
    .instr  (id_instr),
    .imm_out(id_imm)
  );

  wire        wb_RegWrite;
  wire [ 4:0] wb_rd_idx;
  wire [31:0] wb_reg_wd;

  core_regfile rf (
    .clk  (clk),
    .rst_n(rst_n),
    .we   (wb_RegWrite),
    .wd   (wb_reg_wd),
    .rd   (wb_rd_idx),
    .rs1  (id_rs1_idx),
    .rs2  (id_rs2_idx),
    .rd1  (id_rd1),
    .rd2  (id_rd2)
  );

  wire ex_Branch, ex_MemtoReg, ex_MemWrite, ex_ALUSrc, ex_ALUSrcA, ex_RegWrite;
  wire [1:0] ex_Jump;
  wire [3:0] ex_alu_ctrl;
  wire [2:0] ex_funct3;
  wire [31:0] ex_pc, ex_imm, ex_rd1, ex_rd2;
  wire [4:0] ex_rs1_idx, ex_rs2_idx;

  pipe_id_ex reg_id_ex (
    .clk        (clk),
    .rst_n      (rst_n),
    .flush      (id_ex_flush),
    .id_RegWrite(id_RegWrite),
    .id_MemtoReg(id_MemtoReg),
    .id_MemWrite(id_MemWrite),
    .id_MemRead (id_MemRead),
    .id_Branch  (id_Branch),
    .id_Jump    (id_Jump),
    .id_ALUSrc  (id_ALUSrc),
    .id_ALUSrcA (id_ALUSrcA),
    .id_alu_ctrl(id_alu_ctrl),
    .id_funct3  (id_funct3),
    .id_pc      (id_pc),
    .id_rd1     (id_rd1),
    .id_rd2     (id_rd2),
    .id_imm     (id_imm),
    .id_rs1_idx (id_rs1_idx),
    .id_rs2_idx (id_rs2_idx),
    .id_rd_idx  (id_rd_idx),

    .ex_RegWrite(ex_RegWrite),
    .ex_MemtoReg(ex_MemtoReg),
    .ex_MemWrite(ex_MemWrite),
    .ex_MemRead (ex_MemRead),
    .ex_Branch  (ex_Branch),
    .ex_Jump    (ex_Jump),
    .ex_ALUSrc  (ex_ALUSrc),
    .ex_ALUSrcA (ex_ALUSrcA),
    .ex_alu_ctrl(ex_alu_ctrl),
    .ex_funct3  (ex_funct3),
    .ex_pc      (ex_pc),
    .ex_rd1     (ex_rd1),
    .ex_rd2     (ex_rd2),
    .ex_imm     (ex_imm),
    .ex_rs1_idx (ex_rs1_idx),
    .ex_rs2_idx (ex_rs2_idx),
    .ex_rd_idx  (ex_rd_idx)
  );

  wire [31:0] ex_alu_result;
  wire [1:0] forward_a, forward_b;
  wire [31:0] alu_mux_a, alu_mux_b, alu_src_a, alu_src_b;

  wire       mem_RegWrite;
  wire [4:0] mem_rd_idx;

  pipe_forwarding fwd_unit (
    .id_ex_rs1      (ex_rs1_idx),
    .id_ex_rs2      (ex_rs2_idx),
    .ex_mem_RegWrite(mem_RegWrite),
    .ex_mem_rd      (mem_rd_idx),
    .mem_wb_RegWrite(wb_RegWrite),
    .mem_wb_rd      (wb_rd_idx),
    .forward_a      (forward_a),
    .forward_b      (forward_b)
  );

  assign alu_mux_a = (forward_a == 2'b10) ? mem_alu_result :
           (forward_a == 2'b01) ? wb_reg_wd      : ex_rd1;

  assign alu_mux_b = (forward_b == 2'b10) ? mem_alu_result :
           (forward_b == 2'b01) ? wb_reg_wd      : ex_rd2;

  assign alu_src_a = (ex_ALUSrcA) ? ex_pc : alu_mux_a;
  assign alu_src_b = (ex_ALUSrc) ? ex_imm : alu_mux_b;

  core_alu alu_inst (
    .a       (alu_src_a),
    .b       (alu_src_b),
    .alu_ctrl(ex_alu_ctrl),
    .result  (ex_alu_result),
    .zero    ()
  );

  reg branch_cond;
  always @(*) begin
    case (ex_funct3)
      3'b000:  branch_cond = (alu_mux_a == alu_mux_b);
      3'b001:  branch_cond = (alu_mux_a != alu_mux_b);
      3'b100:  branch_cond = ($signed(alu_mux_a) < $signed(alu_mux_b));
      3'b101:  branch_cond = ($signed(alu_mux_a) >= $signed(alu_mux_b));
      3'b110:  branch_cond = (alu_mux_a < alu_mux_b);
      3'b111:  branch_cond = (alu_mux_a >= alu_mux_b);
      default: branch_cond = 1'b0;
    endcase
  end

  assign ex_branch_target = ex_pc + ex_imm;
  assign branch_taken     = ex_Branch & branch_cond;

  wire [31:0] jalr_target = (ex_alu_result & ~32'd1);
  assign jump_target = (ex_Jump == 2'b10) ? jalr_target : ex_branch_target;
  assign jump_taken  = (ex_Jump != 2'b00);

  wire [31:0] ex_result_to_mem = (ex_Jump != 2'b00) ? (ex_pc + 32'd4) : ex_alu_result;

  wire mem_MemRead, mem_MemtoReg, mem_MemWrite;
  wire [ 2:0] mem_funct3;
  wire [31:0] mem_rd2;

  pipe_ex_mem reg_ex_mem (
    .clk          (clk),
    .rst_n        (rst_n),
    .ex_RegWrite  (ex_RegWrite),
    .ex_MemtoReg  (ex_MemtoReg),
    .ex_MemWrite  (ex_MemWrite),
    .ex_MemRead   (ex_MemRead),
    .ex_alu_result(ex_result_to_mem),
    .ex_rd2       (alu_mux_b),
    .ex_rd_idx    (ex_rd_idx),
    .ex_funct3    (ex_funct3),

    .mem_RegWrite  (mem_RegWrite),
    .mem_MemtoReg  (mem_MemtoReg),
    .mem_MemWrite  (mem_MemWrite),
    .mem_MemRead   (mem_MemRead),
    .mem_alu_result(mem_alu_result),
    .mem_rd2       (mem_rd2),
    .mem_rd_idx    (mem_rd_idx),
    .mem_funct3    (mem_funct3)
  );

  reg  [ 3:0] mem_we_mask;
  reg  [31:0] mem_store_data;
  always @(*) begin
    if (mem_MemWrite) begin
      case (mem_funct3[1:0])
        2'b00: begin
          mem_store_data = {4{mem_rd2[7:0]}};
          mem_we_mask    = 4'b0001 << mem_alu_result[1:0];
        end
        2'b01: begin
          mem_store_data = {2{mem_rd2[15:0]}};
          mem_we_mask    = 4'b0011 << {mem_alu_result[1], 1'b0};
        end
        default: begin
          mem_store_data = mem_rd2;
          mem_we_mask    = 4'b1111;
        end
      endcase
    end else begin
      mem_we_mask    = 4'b0000;
      mem_store_data = 32'd0;
    end
  end

  reg  [31:0] mem_load_formatted;
  wire [31:0] shifted_read = data_rdata >> {mem_alu_result[1:0], 3'b000};

  always @(*) begin
    case (mem_funct3)
      3'b000:  mem_load_formatted = {{24{shifted_read[7]}}, shifted_read[7:0]};
      3'b100:  mem_load_formatted = {24'd0, shifted_read[7:0]};
      3'b001:  mem_load_formatted = {{16{shifted_read[15]}}, shifted_read[15:0]};
      3'b101:  mem_load_formatted = {16'd0, shifted_read[15:0]};
      default: mem_load_formatted = data_rdata;
    endcase
  end

  wire wb_MemtoReg;
  wire [31:0] wb_read_data, wb_alu_result;

  pipe_mem_wb reg_mem_wb (
    .clk           (clk),
    .rst_n         (rst_n),
    .mem_RegWrite  (mem_RegWrite),
    .mem_MemtoReg  (mem_MemtoReg),
    .mem_read_data (mem_load_formatted),
    .mem_alu_result(mem_alu_result),
    .mem_rd_idx    (mem_rd_idx),

    .wb_RegWrite  (wb_RegWrite),
    .wb_MemtoReg  (wb_MemtoReg),
    .wb_read_data (wb_read_data),
    .wb_alu_result(wb_alu_result),
    .wb_rd_idx    (wb_rd_idx)
  );

  assign wb_reg_wd = (wb_MemtoReg) ? wb_read_data : wb_alu_result;

  assign instr_addr = if_pc;
  assign data_addr = mem_alu_result;
  assign data_wdata = mem_store_data;
  assign data_wstrb = mem_we_mask;
  assign data_re = mem_MemRead;
endmodule
