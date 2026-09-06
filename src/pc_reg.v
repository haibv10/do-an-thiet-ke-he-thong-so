module pc_reg (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        stall,   // <-- Thêm chân nhận tín hiệu phanh
  input  wire [31:0] pc_next,
  output reg  [31:0] pc
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc <= 32'h00000000;
    else if (!stall)        // <-- Chỉ cập nhật PC khi không bị kẹt
      pc <= pc_next;
  end
endmodule
