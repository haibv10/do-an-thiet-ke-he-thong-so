module core_control (
  input  wire [6:0] opcode,
  input  wire [2:0] funct3,
  input  wire       funct7_5,
  output reg        Branch,
  output reg [1:0]  Jump,      // 00 = none, 01 = JAL, 10 = JALR
  output reg        MemRead,
  output reg        MemtoReg,
  output reg        MemWrite,
  output reg        ALUSrc,   // 0 = register rs2, 1 = immediate, for the B input
  output reg        ALUSrcA,  // 0 = register rs1, 1 = program counter, for the A input
  output reg        RegWrite,
  output reg [3:0]  alu_ctrl
);
  always @(*) begin
    Branch   = 1'b0;
    Jump     = 2'b00;
    MemRead  = 1'b0;
    MemtoReg = 1'b0;
    MemWrite = 1'b0;
    ALUSrc   = 1'b0;
    ALUSrcA  = 1'b0;
    RegWrite = 1'b0;
    alu_ctrl = 4'b0000;

    case (opcode)
      7'b0110011: begin // R-Type
        RegWrite = 1'b1;
        case (funct3)
          3'b000: alu_ctrl = (funct7_5) ? 4'b1000 : 4'b0000;
          3'b001: alu_ctrl = 4'b0001;
          3'b010: alu_ctrl = 4'b0010;
          3'b011: alu_ctrl = 4'b0011;
          3'b100: alu_ctrl = 4'b0100;
          3'b101: alu_ctrl = (funct7_5) ? 4'b1101 : 4'b0101;
          3'b110: alu_ctrl = 4'b0110;
          3'b111: alu_ctrl = 4'b0111;
        endcase
      end

      7'b0010011: begin // I-Type
        ALUSrc   = 1'b1;
        RegWrite = 1'b1;
        case (funct3)
          3'b000: alu_ctrl = 4'b0000;
          3'b001: alu_ctrl = 4'b0001;
          3'b010: alu_ctrl = 4'b0010;
          3'b011: alu_ctrl = 4'b0011;
          3'b100: alu_ctrl = 4'b0100;
          3'b101: alu_ctrl = (funct7_5) ? 4'b1101 : 4'b0101;
          3'b110: alu_ctrl = 4'b0110;
          3'b111: alu_ctrl = 4'b0111;
        endcase
      end

      7'b0110111: begin // LUI
        ALUSrc   = 1'b1;
        RegWrite = 1'b1;
        alu_ctrl = 4'b1111;
      end

      7'b0010111: begin // AUIPC
        ALUSrc   = 1'b1;
        ALUSrcA  = 1'b1;
        RegWrite = 1'b1;
        alu_ctrl = 4'b0000;
      end

      7'b0000011: begin // Load
        ALUSrc   = 1'b1;
        MemtoReg = 1'b1;
        RegWrite = 1'b1;
        MemRead  = 1'b1;
      end

      7'b0100011: begin // Store
        ALUSrc   = 1'b1;
        MemWrite = 1'b1;
      end

      7'b1100011: begin // Branch
        Branch   = 1'b1;
        alu_ctrl = 4'b1000;
      end

      7'b1101111: begin // JAL
        Jump     = 2'b01;
        RegWrite = 1'b1; // the link register, written in EX from pc + 4
      end

      7'b1100111: begin // JALR
        Jump     = 2'b10;
        RegWrite = 1'b1;
        ALUSrc   = 1'b1;
        alu_ctrl = 4'b0000;
      end
    endcase
  end
endmodule
