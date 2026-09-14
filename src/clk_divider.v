module clk_divider #(
    parameter   input_clk_freq  = 50_000_000,       // input clock
    parameter   output_clk_freq = 1_000_000         // output clock 1MHz = 1us
)(
    input       clk,
    output      clk_1MHz                                   
);
    reg         clk_1MHz_temp = 0;
    integer     count = 0;
    integer     half_cycle = input_clk_freq / output_clk_freq / 2 - 1; // nua chu ky
    
    always @(posedge clk) begin
        if (count == half_cycle) begin
            clk_1MHz_temp <= ~clk_1MHz_temp;
            count <= 0;
        end else
            count <= count + 1;
    end

    assign clk_1MHz = clk_1MHz_temp;
    
endmodule
