module gpio_mmio (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [31:0] a,
  input  wire [31:0] wd,
  output wire [31:0] rd,
  output reg         led,
  input  wire        btn_in
);

  // The decoder has already matched the region, so only the offset matters:
  //   0x00 -> LED, 0x04 -> button

  // Two stages before software can see the pin, so a press landing near a clock
  // edge resolves here instead of propagating a metastable bit into the CPU.
  // Reset high because the button is active low with a pull-up.
  reg btn_meta, btn_sync;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      btn_meta <= 1'b1;
      btn_sync <= 1'b1;
    end else begin
      btn_meta <= btn_in;
      btn_sync <= btn_meta;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led <= 1'b0;
    end else if (we && (a[7:0] == 8'h00)) begin
      led <= wd[0];
    end
  end

  assign rd = (a[7:0] == 8'h00) ? {31'd0, led} :
        (a[7:0] == 8'h04) ? {31'd0, btn_sync} : 32'd0;

endmodule
