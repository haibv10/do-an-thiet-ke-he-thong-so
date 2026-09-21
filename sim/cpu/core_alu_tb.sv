`timescale 1ns/1ps

module core_alu_tb;
  logic [31:0] a;
  logic [31:0] b;
  logic [3:0] alu_ctrl;
  logic [31:0] result;
  logic zero;

  core_alu dut (.*);

  task automatic check(
    input logic [3:0] control,
    input logic [31:0] lhs,
    input logic [31:0] rhs,
    input logic [31:0] expected
  );
    alu_ctrl = control;
    a = lhs;
    b = rhs;
    #1;
    if (result !== expected) begin
      $fatal(1, "control=%h a=%h b=%h result=%h expected=%h",
             control, lhs, rhs, result, expected);
    end
    if (zero !== (expected == 32'd0)) begin
      $fatal(1, "zero flag mismatch for result=%h", expected);
    end
  endtask

  initial begin
    check(4'b0000, 32'd7, 32'd5, 32'd12);
    check(4'b1000, 32'd7, 32'd5, 32'd2);
    check(4'b0111, 32'hf0f0_55aa, 32'h0ff0_0f0f, 32'h00f0_050a);
    check(4'b0110, 32'hf000_0055, 32'h0f00_00aa, 32'hff00_00ff);
    check(4'b0100, 32'haaaa_5555, 32'hffff_0000, 32'h5555_5555);
    check(4'b0001, 32'd1, 32'd31, 32'h8000_0000);
    check(4'b0101, 32'h8000_0000, 32'd31, 32'd1);
    check(4'b1101, 32'h8000_0000, 32'd31, 32'hffff_ffff);
    check(4'b0010, 32'hffff_ffff, 32'd1, 32'd1);
    check(4'b0011, 32'hffff_ffff, 32'd1, 32'd0);
    check(4'b1111, 32'hdead_beef, 32'h1234_5000, 32'h1234_5000);
    check(4'b0000, 32'd0, 32'd0, 32'd0);
    $display("core_alu_tb: PASS");
    $finish;
  end
endmodule
