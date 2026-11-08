`timescale 1ns / 1ps
// One transaction, cycle counts corresponding to a 27 MHz controller clock.
module dht11_sensor_model(input wire clk, inout wire data);
  reg drive_low = 0;
  assign data = drive_low ? 1'b0 : 1'bz;

  task automatic respond(input logic [39:0] frame);
    integer bit_index;
    wait (data === 1'b0);
    @(posedge data);
    repeat (540) @(negedge clk);
    drive_low = 1;
    repeat (2160) @(negedge clk);
    drive_low = 0;
    repeat (2160) @(negedge clk);
    for (bit_index = 39; bit_index >= 0; bit_index = bit_index - 1) begin
      drive_low = 1;
      repeat (1350) @(negedge clk);
      drive_low = 0;
      if (frame[bit_index]) repeat (1890) @(negedge clk);
      else repeat (702) @(negedge clk);
    end
    drive_low = 1;
    repeat (1350) @(negedge clk);
    drive_low = 0;
  endtask
endmodule
