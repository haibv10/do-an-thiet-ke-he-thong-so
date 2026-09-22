module core_immediate(
  input  wire [31:0] instr,
  output reg  [31:0] imm_out
);
  always @(*) begin
    case (instr[6:0])
      7'b0000011, 7'b0010011, 7'b1100111: // I-type: load, ALU immediate, JALR
        imm_out = {{20{instr[31]}}, instr[31:20]};

      7'b0100011: // S-type: store
        imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

      7'b1100011: // B-type: branch
        imm_out = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};

      7'b0110111, 7'b0010111: // U-type: LUI, AUIPC
        imm_out = {instr[31:12], 12'b0};

      // J-type. The encoding scatters the immediate bits so that every format
      // keeps the sign bit in instr[31].
      7'b1101111:
        imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

      default:
        imm_out = 32'b0;
    endcase
  end
endmodule
