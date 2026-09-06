module imm_gen(
  input  wire [31:0] instr,
  output reg  [31:0] imm_out
);
  always @(*) begin
    case (instr[6:0])
      7'b0000011, 7'b0010011, 7'b1100111: // Lw, ALU-I, JALR (I-Type)
        imm_out = {{20{instr[31]}}, instr[31:20]};

      7'b0100011: // Sw (S-Type)
        imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

      7'b1100011: // Branch (B-Type)
        imm_out = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};

      7'b0110111: // LUI (U-Type)
        imm_out = {instr[31:12], 12'b0};

      7'b1101111: // JAL (J-Type) - Sắp xếp lại bit cho Jump
        imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

      default:
        imm_out = 32'b0;
    endcase
  end
endmodule
