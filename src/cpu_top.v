module cpu_top (
  input  wire clk,
  input  wire rst_n,
  output wire led_out,
  input  wire btn_in,
  input  wire uart_rx_in,
  output wire uart_tx_out,
  inout wire i2c_sda,
  inout wire i2c_scl
);

  // ===========================================================================
  // 0. KHAI BÁO CÁC TÍN HIỆU HAZARD & FLUSH (CHỐNG KẸT & RẼ NHÁNH)
  // ===========================================================================
  wire stall;
  wire branch_taken;
  wire jump_taken;
  wire pc_change_taken = branch_taken | jump_taken;

  // Nếu rẽ nhánh: Xóa lệnh đang nạp ở IF.
  wire if_id_flush = pc_change_taken;
  // Nếu rẽ nhánh hoặc dính kẹt dữ liệu (stall): Xóa cờ điều khiển ở ID để tạo "bong bóng"
  wire id_ex_flush = pc_change_taken | stall;

  // ===========================================================================
  // TRẠM 1: IF (Instruction Fetch) - LẤY LỆNH
  // ===========================================================================
  wire [31:0] if_pc, if_next_pc, if_instr;
  wire [31:0] ex_branch_target, jump_target;
  pc_reg pc_register (
    .clk(clk), .rst_n(rst_n), .stall(stall),
    .pc_next(if_next_pc), .pc(if_pc)
  );

  // Đa hợp quyết định hướng đi của PC (Được quyết định ở tầng EX)
  assign if_next_pc = (jump_taken)   ? jump_target :
            (branch_taken) ? ex_branch_target :
                    (if_pc + 32'd4);

  imem rom (
    .clk(clk), // <-- BỔ SUNG CLOCK ĐỂ SUY DIỄN BLOCK RAM
    .a(if_pc),
    .rd(if_instr)
  );

  wire [31:0] id_pc, id_instr;
  pipe_if_id reg_if_id (
    .clk(clk), .rst_n(rst_n), .stall(stall), .flush(if_id_flush),
    .if_pc(if_pc), .if_instr(if_instr),
    .id_pc(id_pc), .id_instr(id_instr)
  );

  // ===========================================================================
  // TRẠM 2: ID (Instruction Decode) - GIẢI MÃ LỆNH
  // ===========================================================================
  wire id_Branch, id_MemRead, id_MemtoReg, id_MemWrite, id_ALUSrc, id_RegWrite;
  wire [1:0]  id_Jump;
  wire [3:0]  id_alu_ctrl;
  wire [31:0] id_imm, id_rd1, id_rd2;

  wire [4:0]  id_rs1_idx = id_instr[19:15];
  wire [4:0]  id_rs2_idx = id_instr[24:20];
  wire [4:0]  id_rd_idx  = id_instr[11:7];
  wire [2:0]  id_funct3  = id_instr[14:12];

  wire        ex_MemRead;
  wire [4:0]  ex_rd_idx;

  // Khối phát hiện kẹt dữ liệu Load-Use (Bảo vệ thanh ghi đọc từ ngoại vi)
  hazard_detection_unit hdu (
    .if_id_rs1(id_rs1_idx), .if_id_rs2(id_rs2_idx),
    .id_ex_MemRead(ex_MemRead), .id_ex_rd(ex_rd_idx),
    .stall(stall)
  );

  control_unit ctrl (
    .opcode(id_instr[6:0]),
    .funct3(id_funct3),
    .funct7_5(id_instr[30]),
    .Branch(id_Branch),
    .Jump(id_Jump),
    .MemRead(id_MemRead), .MemtoReg(id_MemtoReg),
    .MemWrite(id_MemWrite), .ALUSrc(id_ALUSrc), .RegWrite(id_RegWrite),
    .alu_ctrl(id_alu_ctrl)
  );

  imm_gen ig (
    .instr(id_instr),
    .imm_out(id_imm)
  );

  wire wb_RegWrite;
  wire [4:0]  wb_rd_idx;
  wire [31:0] wb_reg_wd;

  regfile rf (
    .clk(clk), .rst_n(rst_n), .we(wb_RegWrite), .wd(wb_reg_wd),
    .rd(wb_rd_idx), .rs1(id_rs1_idx), .rs2(id_rs2_idx),
    .rd1(id_rd1), .rd2(id_rd2)
  );

  // --- BĂNG CHUYỀN ID/EX ---
  wire ex_Branch, ex_MemtoReg, ex_MemWrite, ex_ALUSrc, ex_RegWrite;
  wire [1:0]  ex_Jump;
  wire [3:0]  ex_alu_ctrl;
  wire [2:0]  ex_funct3;
  wire [31:0] ex_pc, ex_imm, ex_rd1, ex_rd2;
  wire [4:0]  ex_rs1_idx, ex_rs2_idx;

  pipe_id_ex reg_id_ex (
    .clk(clk), .rst_n(rst_n), .flush(id_ex_flush),
    .id_RegWrite(id_RegWrite), .id_MemtoReg(id_MemtoReg), .id_MemWrite(id_MemWrite),
    .id_MemRead(id_MemRead), .id_Branch(id_Branch), .id_Jump(id_Jump), .id_ALUSrc(id_ALUSrc),
    .id_alu_ctrl(id_alu_ctrl), .id_funct3(id_funct3),
    .id_pc(id_pc), .id_rd1(id_rd1), .id_rd2(id_rd2), .id_imm(id_imm),
    .id_rs1_idx(id_rs1_idx), .id_rs2_idx(id_rs2_idx), .id_rd_idx(id_rd_idx),

    .ex_RegWrite(ex_RegWrite), .ex_MemtoReg(ex_MemtoReg), .ex_MemWrite(ex_MemWrite),
    .ex_MemRead(ex_MemRead), .ex_Branch(ex_Branch), .ex_Jump(ex_Jump), .ex_ALUSrc(ex_ALUSrc),
    .ex_alu_ctrl(ex_alu_ctrl), .ex_funct3(ex_funct3),
    .ex_pc(ex_pc), .ex_rd1(ex_rd1), .ex_rd2(ex_rd2), .ex_imm(ex_imm),
    .ex_rs1_idx(ex_rs1_idx), .ex_rs2_idx(ex_rs2_idx), .ex_rd_idx(ex_rd_idx)
  );

  // ===========================================================================
  // TRẠM 3: EX (Execute) - THỰC THI & CHUYỂN TIẾP (FORWARDING)
  // ===========================================================================
  wire [31:0] ex_alu_result;
  wire        ex_zero;
  wire [1:0]  forward_a, forward_b;
  wire [31:0] alu_mux_a, alu_mux_b, alu_src_b;

  wire        mem_RegWrite;
  wire [4:0]  mem_rd_idx;
  wire [31:0] mem_alu_result;

  forwarding_unit fwd_unit (
    .id_ex_rs1(ex_rs1_idx), .id_ex_rs2(ex_rs2_idx),
    .ex_mem_RegWrite(mem_RegWrite), .ex_mem_rd(mem_rd_idx),
    .mem_wb_RegWrite(wb_RegWrite), .mem_wb_rd(wb_rd_idx),
    .forward_a(forward_a), .forward_b(forward_b)
  );

  assign alu_mux_a = (forward_a == 2'b10) ? mem_alu_result :
           (forward_a == 2'b01) ? wb_reg_wd      : ex_rd1;

  assign alu_mux_b = (forward_b == 2'b10) ? mem_alu_result :
           (forward_b == 2'b01) ? wb_reg_wd      : ex_rd2;

  assign alu_src_b = (ex_ALUSrc) ? ex_imm : alu_mux_b;

  alu alu_inst (
    .a(alu_mux_a),
    .b(alu_src_b),
    .alu_ctrl(ex_alu_ctrl),
    .result(ex_alu_result),
    .zero(ex_zero)
  );

  // Đánh giá đa điều kiện Branch
  reg branch_cond;
  always @(*) begin
    case (ex_funct3)
      3'b000: branch_cond = (alu_mux_a == alu_mux_b);                  // BEQ
      3'b001: branch_cond = (alu_mux_a != alu_mux_b);                  // BNE
      3'b100: branch_cond = ($signed(alu_mux_a) < $signed(alu_mux_b)); // BLT
      3'b101: branch_cond = ($signed(alu_mux_a) >= $signed(alu_mux_b));// BGE
      3'b110: branch_cond = (alu_mux_a < alu_mux_b);                   // BLTU
      3'b111: branch_cond = (alu_mux_a >= alu_mux_b);                  // BGEU
      default: branch_cond = 1'b0;
    endcase
  end

  // Xử lý địa chỉ nhảy JUMP & BRANCH
  assign ex_branch_target = ex_pc + ex_imm;
  assign branch_taken     = ex_Branch & branch_cond;

  wire [31:0] jalr_target = (ex_alu_result & ~32'd1); // JALR ép bit cuối về 0
  assign jump_target = (ex_Jump == 2'b10) ? jalr_target : ex_branch_target;
  assign jump_taken  = (ex_Jump != 2'b00);

  // Đánh tráo kết quả: Lưu PC+4 vào Register File nếu là lệnh JAL/JALR
  wire [31:0] ex_result_to_mem = (ex_Jump != 2'b00) ? (ex_pc + 32'd4) : ex_alu_result;

  // --- BĂNG CHUYỀN EX/MEM ---
  wire mem_Branch, mem_MemRead, mem_MemtoReg, mem_MemWrite, mem_zero;
  wire [2:0]  mem_funct3;
  wire [31:0] mem_branch_target, mem_rd2;

  pipe_ex_mem reg_ex_mem (
    .clk(clk), .rst_n(rst_n),
    .ex_RegWrite(ex_RegWrite), .ex_MemtoReg(ex_MemtoReg), .ex_MemWrite(ex_MemWrite),
    .ex_MemRead(ex_MemRead), .ex_Branch(ex_Branch), .ex_branch_target(ex_branch_target),
    .ex_zero(ex_zero), .ex_alu_result(ex_result_to_mem), .ex_rd2(alu_mux_b), .ex_rd_idx(ex_rd_idx),
    .ex_funct3(ex_funct3),

    .mem_RegWrite(mem_RegWrite), .mem_MemtoReg(mem_MemtoReg), .mem_MemWrite(mem_MemWrite),
    .mem_MemRead(mem_MemRead), .mem_Branch(mem_Branch), .mem_branch_target(mem_branch_target),
    .mem_zero(mem_zero), .mem_alu_result(mem_alu_result), .mem_rd2(mem_rd2), .mem_rd_idx(mem_rd_idx),
    .mem_funct3(mem_funct3)
  );

  // ===========================================================================
  // TRẠM 4: MEM (Memory) - MẠCH CĂN CHỈNH BYTE & MMIO
  // ===========================================================================
  wire we_gpio, we_uart, we_i2c;
  wire [3:0]  we_dmem;
  wire [31:0] dmem_rd, gpio_rd, uart_rd, i2c_rd, mem_read_data;

  wire i2c_tick;

  // 1. CĂN CHỈNH GHI (SB, SH, SW)
  reg [3:0]  mem_we_mask;
  reg [31:0] mem_store_data;
  always @(*) begin
    if (mem_MemWrite) begin
      case (mem_funct3[1:0])
        2'b00: begin // SB (Store Byte)
          mem_store_data = {4{mem_rd2[7:0]}};
          mem_we_mask    = 4'b0001 << mem_alu_result[1:0];
        end
        2'b01: begin // SH (Store Halfword)
          mem_store_data = {2{mem_rd2[15:0]}};
          mem_we_mask    = 4'b0011 << {mem_alu_result[1], 1'b0};
        end
        default: begin // SW (Store Word)
          mem_store_data = mem_rd2;
          mem_we_mask    = 4'b1111;
        end
      endcase
    end else begin
      mem_we_mask    = 4'b0000;
      mem_store_data = 32'd0;
    end
  end

  address_decoder bus_matrix (
    .addr(mem_alu_result), .we_mask(mem_we_mask),
    .we_dmem(we_dmem), .we_gpio(we_gpio), .we_uart(we_uart), .we_i2c(we_i2c),
    .rd_dmem(dmem_rd), .rd_gpio(gpio_rd), .rd_uart(uart_rd), .rd_i2c(i2c_rd), .rd_out(mem_read_data)
  );

  dmem ram (
    .clk(clk), .we(we_dmem), .a(mem_alu_result),
    .wd(mem_store_data), .rd(dmem_rd)
  );

  gpio led_controller (
    .clk(clk), .rst_n(rst_n), .we(we_gpio), .a(mem_alu_result),
    .wd(mem_store_data), .rd(gpio_rd), .led(led_out), .btn_in(btn_in)
  );

  wire uart_read = mem_MemRead && (mem_alu_result[31:28] == 4'h5);

  uart_mmio serial_port (
    .clk(clk), .rst_n(rst_n), .we(we_uart), .re(uart_read),
    .a(mem_alu_result), .wd(mem_store_data), .rx(uart_rx_in),
    .rd(uart_rd), .tx(uart_tx_out)
  );

  clock_enable_divider #(.divider(27)) i2c_clock_enable (
    .clk(clk), .rst_n(rst_n), .tick(i2c_tick)
  );

  i2c_mmio lcd_port (
    .clk(clk), .tick(i2c_tick), .rst_n(rst_n), .we(we_i2c), .a(mem_alu_result),
    .wd(mem_store_data), .rd(i2c_rd), .sda(i2c_sda), .scl(i2c_scl)
  );

  // 2. CĂN CHỈNH ĐỌC (LB, LBU, LH, LHU, LW)
  reg  [31:0] mem_load_formatted;
  wire [31:0] shifted_read = mem_read_data >> {mem_alu_result[1:0], 3'b000};

  always @(*) begin
    case (mem_funct3)
      3'b000: mem_load_formatted = {{24{shifted_read[7]}},  shifted_read[7:0]};  // LB  (Mở rộng dấu)
      3'b100: mem_load_formatted = { 24'd0,                 shifted_read[7:0]};  // LBU (Thêm 0)
      3'b001: mem_load_formatted = {{16{shifted_read[15]}}, shifted_read[15:0]}; // LH  (Mở rộng dấu)
      3'b101: mem_load_formatted = { 16'd0,                 shifted_read[15:0]}; // LHU (Thêm 0)
      default: mem_load_formatted = mem_read_data;                               // LW
    endcase
  end

  // --- BĂNG CHUYỀN MEM/WB ---
  wire wb_MemtoReg;
  wire [31:0] wb_read_data, wb_alu_result;

  pipe_mem_wb reg_mem_wb (
    .clk(clk), .rst_n(rst_n),
    .mem_RegWrite(mem_RegWrite), .mem_MemtoReg(mem_MemtoReg),
    .mem_read_data(mem_load_formatted),
    .mem_alu_result(mem_alu_result), .mem_rd_idx(mem_rd_idx),

    .wb_RegWrite(wb_RegWrite), .wb_MemtoReg(wb_MemtoReg),
    .wb_read_data(wb_read_data), .wb_alu_result(wb_alu_result), .wb_rd_idx(wb_rd_idx)
  );

  // ===========================================================================
  // TRẠM 5: WB (Write Back) - GHI TRẢ VỀ TẬP THANH GHI
  // ===========================================================================
  assign wb_reg_wd = (wb_MemtoReg) ? wb_read_data : wb_alu_result;

endmodule
