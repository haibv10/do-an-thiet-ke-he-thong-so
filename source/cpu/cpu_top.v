module cpu_top #(
  parameter UART_CLKS_PER_BIT = 234,
  parameter SPI_CLK_DIV = 2
) (
  input  wire clk,
  input  wire rst_n,
  output wire led_out,
  input  wire uart_rx_in,
  output wire uart_tx_out,
  inout wire i2c_sda,
  inout wire i2c_scl,
  output wire spi_sck_out,
  output wire spi_mosi_out,
  output wire spi_cs_n_out,
  output wire spi_dc_out,
  output wire spi_rst_n_out
);

  // Every sequential block below runs on the synchronised reset, never on the
  // raw pin.
  wire rst_n_sync;
  reset_sync reset_bridge (
    .clk(clk), .rst_n_in(rst_n), .rst_n_out(rst_n_sync)
  );

  // --- Hazard and flush ---
  wire stall;
  wire branch_taken;
  wire jump_taken;
  wire pc_change_taken = branch_taken | jump_taken;

  // Branches resolve in EX, so the two instructions already fetched behind one
  // have to be discarded. A load-use stall reuses the same bubble.
  wire if_id_flush = pc_change_taken;
  wire id_ex_flush = pc_change_taken | stall;

  // --- IF: instruction fetch ---
  wire [31:0] if_pc, if_next_pc, if_instr;
  wire [31:0] ex_branch_target, jump_target;
  wire [31:0] mem_alu_result;  // MEM stage address, also drives the ROM data port
  wire [31:0] rom_rd;          // ROM word read over the data bus
  core_pc pc_register (
    .clk(clk), .rst_n(rst_n_sync), .stall(stall),
    .pc_next(if_next_pc), .pc(if_pc)
  );

  assign if_next_pc = (jump_taken)   ? jump_target :
            (branch_taken) ? ex_branch_target :
                    (if_pc + 32'd4);

  // The second port lets loads reach .rodata and the load image of .data, both
  // of which the linker puts in ROM.
  mem_instruction_rom rom (
    .clk(clk),
    .a(if_pc),
    .rd(if_instr),
    .a_data(mem_alu_result),
    .rd_data(rom_rd)
  );

  wire [31:0] id_pc, id_instr;
  pipe_if_id reg_if_id (
    .clk(clk), .rst_n(rst_n_sync), .stall(stall), .flush(if_id_flush),
    .if_pc(if_pc), .if_instr(if_instr),
    .id_pc(id_pc), .id_instr(id_instr)
  );

  // --- ID: instruction decode ---
  wire id_Branch, id_MemRead, id_MemtoReg, id_MemWrite, id_ALUSrc, id_ALUSrcA, id_RegWrite;
  wire id_UsesRs1, id_UsesRs2;
  wire id_Fence;
  wire [1:0]  id_Jump;
  wire [3:0]  id_alu_ctrl;
  wire [31:0] id_imm, id_rd1, id_rd2;

  wire [4:0]  id_rs1_idx = id_instr[19:15];
  wire [4:0]  id_rs2_idx = id_instr[24:20];
  wire [4:0]  id_rd_idx  = id_instr[11:7];
  wire [2:0]  id_funct3  = id_instr[14:12];

  wire        ex_MemRead;
  wire [4:0]  ex_rd_idx;

  pipe_hazard hdu (
    .if_id_rs1(id_rs1_idx), .if_id_rs2(id_rs2_idx),
    .if_id_UsesRs1(id_UsesRs1), .if_id_UsesRs2(id_UsesRs2),
    .id_ex_MemRead(ex_MemRead), .id_ex_rd(ex_rd_idx),
    .stall(stall)
  );

  core_control ctrl (
    .opcode(id_instr[6:0]),
    .funct3(id_funct3),
    .funct7_5(id_instr[30]),
    .Branch(id_Branch),
    .Jump(id_Jump),
    .MemRead(id_MemRead), .MemtoReg(id_MemtoReg),
    .MemWrite(id_MemWrite), .ALUSrc(id_ALUSrc), .ALUSrcA(id_ALUSrcA),
    .RegWrite(id_RegWrite), .UsesRs1(id_UsesRs1), .UsesRs2(id_UsesRs2), .Fence(id_Fence),
    .alu_ctrl(id_alu_ctrl)
  );

  core_immediate ig (
    .instr(id_instr),
    .imm_out(id_imm)
  );

  wire wb_RegWrite;
  wire [4:0]  wb_rd_idx;
  wire [31:0] wb_reg_wd;

  core_regfile rf (
    .clk(clk), .rst_n(rst_n_sync), .we(wb_RegWrite), .wd(wb_reg_wd),
    .rd(wb_rd_idx), .rs1(id_rs1_idx), .rs2(id_rs2_idx),
    .rd1(id_rd1), .rd2(id_rd2)
  );

  wire ex_Branch, ex_MemtoReg, ex_MemWrite, ex_ALUSrc, ex_ALUSrcA, ex_RegWrite;
  wire [1:0]  ex_Jump;
  wire [3:0]  ex_alu_ctrl;
  wire [2:0]  ex_funct3;
  wire [31:0] ex_pc, ex_imm, ex_rd1, ex_rd2;
  wire [4:0]  ex_rs1_idx, ex_rs2_idx;

  pipe_id_ex reg_id_ex (
    .clk(clk), .rst_n(rst_n_sync), .flush(id_ex_flush),
    .id_RegWrite(id_RegWrite), .id_MemtoReg(id_MemtoReg), .id_MemWrite(id_MemWrite),
    .id_MemRead(id_MemRead), .id_Branch(id_Branch), .id_Jump(id_Jump),
    .id_ALUSrc(id_ALUSrc), .id_ALUSrcA(id_ALUSrcA),
    .id_alu_ctrl(id_alu_ctrl), .id_funct3(id_funct3),
    .id_pc(id_pc), .id_rd1(id_rd1), .id_rd2(id_rd2), .id_imm(id_imm),
    .id_rs1_idx(id_rs1_idx), .id_rs2_idx(id_rs2_idx), .id_rd_idx(id_rd_idx),

    .ex_RegWrite(ex_RegWrite), .ex_MemtoReg(ex_MemtoReg), .ex_MemWrite(ex_MemWrite),
    .ex_MemRead(ex_MemRead), .ex_Branch(ex_Branch), .ex_Jump(ex_Jump),
    .ex_ALUSrc(ex_ALUSrc), .ex_ALUSrcA(ex_ALUSrcA),
    .ex_alu_ctrl(ex_alu_ctrl), .ex_funct3(ex_funct3),
    .ex_pc(ex_pc), .ex_rd1(ex_rd1), .ex_rd2(ex_rd2), .ex_imm(ex_imm),
    .ex_rs1_idx(ex_rs1_idx), .ex_rs2_idx(ex_rs2_idx), .ex_rd_idx(ex_rd_idx)
  );

  // --- EX: execute and operand forwarding ---
  wire [31:0] ex_alu_result;
  wire        ex_zero;
  wire [1:0]  forward_a, forward_b;
  wire [31:0] alu_mux_a, alu_mux_b, alu_src_a, alu_src_b;

  wire        mem_RegWrite;
  wire [4:0]  mem_rd_idx;

  pipe_forwarding fwd_unit (
    .id_ex_rs1(ex_rs1_idx), .id_ex_rs2(ex_rs2_idx),
    .ex_mem_RegWrite(mem_RegWrite), .ex_mem_rd(mem_rd_idx),
    .mem_wb_RegWrite(wb_RegWrite), .mem_wb_rd(wb_rd_idx),
    .forward_a(forward_a), .forward_b(forward_b)
  );

  assign alu_mux_a = (forward_a == 2'b10) ? mem_alu_result :
           (forward_a == 2'b01) ? wb_reg_wd      : ex_rd1;

  assign alu_mux_b = (forward_b == 2'b10) ? mem_alu_result :
           (forward_b == 2'b01) ? wb_reg_wd      : ex_rd2;

  // AUIPC is the only instruction whose first operand is its own PC.
  assign alu_src_a = (ex_ALUSrcA) ? ex_pc : alu_mux_a;
  assign alu_src_b = (ex_ALUSrc)  ? ex_imm : alu_mux_b;

  core_alu alu_inst (
    .a(alu_src_a),
    .b(alu_src_b),
    .alu_ctrl(ex_alu_ctrl),
    .result(ex_alu_result),
    .zero(ex_zero)
  );

  // Comparing the forwarded operands, not ex_rd1/ex_rd2, keeps a branch that
  // depends on the instruction right before it from reading stale registers.
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

  assign ex_branch_target = ex_pc + ex_imm;
  assign branch_taken     = ex_Branch & branch_cond;

  wire [31:0] jalr_target = (ex_alu_result & ~32'd1); // the spec mandates clearing bit 0
  assign jump_target = (ex_Jump == 2'b10) ? jalr_target : ex_branch_target;
  assign jump_taken  = (ex_Jump != 2'b00);

  wire [31:0] ex_result_to_mem = (ex_Jump != 2'b00) ? (ex_pc + 32'd4) : ex_alu_result;

  wire mem_Branch, mem_MemRead, mem_MemtoReg, mem_MemWrite, mem_zero;
  wire [2:0]  mem_funct3;
  wire [31:0] mem_branch_target, mem_rd2;

  pipe_ex_mem reg_ex_mem (
    .clk(clk), .rst_n(rst_n_sync),
    .ex_RegWrite(ex_RegWrite), .ex_MemtoReg(ex_MemtoReg), .ex_MemWrite(ex_MemWrite),
    .ex_MemRead(ex_MemRead), .ex_Branch(ex_Branch), .ex_branch_target(ex_branch_target),
    .ex_zero(ex_zero), .ex_alu_result(ex_result_to_mem), .ex_rd2(alu_mux_b), .ex_rd_idx(ex_rd_idx),
    .ex_funct3(ex_funct3),

    .mem_RegWrite(mem_RegWrite), .mem_MemtoReg(mem_MemtoReg), .mem_MemWrite(mem_MemWrite),
    .mem_MemRead(mem_MemRead), .mem_Branch(mem_Branch), .mem_branch_target(mem_branch_target),
    .mem_zero(mem_zero), .mem_alu_result(mem_alu_result), .mem_rd2(mem_rd2), .mem_rd_idx(mem_rd_idx),
    .mem_funct3(mem_funct3)
  );

  // --- MEM: memory, byte alignment and MMIO ---
  wire we_gpio, we_uart, we_i2c, we_spi;
  wire [3:0]  we_dmem;
  wire [31:0] dmem_rd, gpio_rd, uart_rd, i2c_rd, spi_rd, mem_read_data;

  wire i2c_tick;

  // Sub-word stores replicate the payload across the bus and pick the target
  // byte lanes with the write mask, so the RAM needs no read-modify-write.
  reg [3:0]  mem_we_mask;
  reg [31:0] mem_store_data;
  always @(*) begin
    if (mem_MemWrite) begin
      case (mem_funct3[1:0])
        2'b00: begin // SB
          mem_store_data = {4{mem_rd2[7:0]}};
          mem_we_mask    = 4'b0001 << mem_alu_result[1:0];
        end
        2'b01: begin // SH
          mem_store_data = {2{mem_rd2[15:0]}};
          mem_we_mask    = 4'b0011 << {mem_alu_result[1], 1'b0};
        end
        default: begin // SW
          mem_store_data = mem_rd2;
          mem_we_mask    = 4'b1111;
        end
      endcase
    end else begin
      mem_we_mask    = 4'b0000;
      mem_store_data = 32'd0;
    end
  end

  cpu_address_decoder bus_matrix (
    .addr(mem_alu_result), .we_mask(mem_we_mask),
    .we_dmem(we_dmem), .we_gpio(we_gpio), .we_uart(we_uart), .we_i2c(we_i2c),
    .we_spi(we_spi),
    .rd_rom(rom_rd), .rd_dmem(dmem_rd), .rd_gpio(gpio_rd), .rd_uart(uart_rd),
    .rd_i2c(i2c_rd), .rd_spi(spi_rd), .rd_out(mem_read_data)
  );

  mem_data_ram ram (
    .clk(clk), .we(we_dmem), .a(mem_alu_result),
    .wd(mem_store_data), .rd(dmem_rd)
  );

  gpio_mmio led_controller (
    .clk(clk), .rst_n(rst_n_sync), .we(we_gpio), .a(mem_alu_result),
    .wd(mem_store_data), .rd(gpio_rd), .led(led_out)
  );

  wire uart_read = mem_MemRead && (mem_alu_result[31:28] == 4'h5);

  uart_mmio #(
    .CLKS_PER_BIT(UART_CLKS_PER_BIT)
  ) serial_port (
    .clk(clk), .rst_n(rst_n_sync), .we(we_uart), .re(uart_read),
    .a(mem_alu_result), .wd(mem_store_data), .rx(uart_rx_in),
    .rd(uart_rd), .tx(uart_tx_out)
  );

  clock_enable #(.divider(27)) i2c_clock_enable (
    .clk(clk), .rst_n(rst_n_sync), .tick(i2c_tick)
  );

  pcf8574_lcd_mmio lcd_port (
    .clk(clk), .tick(i2c_tick), .rst_n(rst_n_sync), .we(we_i2c), .a(mem_alu_result),
    .wd(mem_store_data), .rd(i2c_rd), .sda(i2c_sda), .scl(i2c_scl)
  );

  spi_mmio #(
    .CLK_DIV(SPI_CLK_DIV)
  ) display_port (
    .clk(clk), .rst_n(rst_n_sync), .we(we_spi), .a(mem_alu_result),
    .wd(mem_store_data), .rd(spi_rd),
    .spi_sck(spi_sck_out), .spi_mosi(spi_mosi_out), .spi_cs_n(spi_cs_n_out),
    .spi_dc(spi_dc_out), .spi_rst_n(spi_rst_n_out)
  );

  // Loads come back as a full word and are shifted down to the addressed byte.
  reg  [31:0] mem_load_formatted;
  wire [31:0] shifted_read = mem_read_data >> {mem_alu_result[1:0], 3'b000};

  always @(*) begin
    case (mem_funct3)
      3'b000: mem_load_formatted = {{24{shifted_read[7]}},  shifted_read[7:0]}; // LB
      3'b100: mem_load_formatted = { 24'd0,                 shifted_read[7:0]}; // LBU
      3'b001: mem_load_formatted = {{16{shifted_read[15]}}, shifted_read[15:0]}; // LH
      3'b101: mem_load_formatted = { 16'd0,                 shifted_read[15:0]}; // LHU
      default: mem_load_formatted = mem_read_data;                               // LW
    endcase
  end

  wire wb_MemtoReg;
  wire [31:0] wb_read_data, wb_alu_result;

  pipe_mem_wb reg_mem_wb (
    .clk(clk), .rst_n(rst_n_sync),
    .mem_RegWrite(mem_RegWrite), .mem_MemtoReg(mem_MemtoReg),
    .mem_read_data(mem_load_formatted),
    .mem_alu_result(mem_alu_result), .mem_rd_idx(mem_rd_idx),

    .wb_RegWrite(wb_RegWrite), .wb_MemtoReg(wb_MemtoReg),
    .wb_read_data(wb_read_data), .wb_alu_result(wb_alu_result), .wb_rd_idx(wb_rd_idx)
  );

  // --- WB: write back ---
  assign wb_reg_wd = (wb_MemtoReg) ? wb_read_data : wb_alu_result;

endmodule
