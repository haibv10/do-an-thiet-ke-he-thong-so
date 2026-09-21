`timescale 1ns/1ps

// A behavioural I2C slave: address match, a register pointer set by the first
// byte of a write, and auto-increment on every byte after it. That is the
// shape almost every register-mapped I2C device presents, so the master can be
// exercised against it without naming a part.
module i2c_slave_model #(
  parameter logic [6:0] ADDRESS = 7'h50,
  parameter int REGISTERS = 19
) (inout wire sda, input wire scl);

  logic [7:0] regs [0:REGISTERS-1];
  logic drive_low = 1'b0;
  assign sda = drive_low ? 1'b0 : 1'bz;

  typedef enum int {IDLE, ADDR, ADDR_ACK, RX, RX_ACK, TX, TX_ACK, SILENT} state_t;
  state_t state = IDLE;

  logic [7:0] rx_shift = 8'h00;
  logic [7:0] tx_byte = 8'h00;
  int bit_index = 0;
  int pointer = 0;
  logic reading = 1'b0;
  logic pointer_written = 1'b0;
  logic master_ack = 1'b0;
  int start_conditions = 0;
  int stop_conditions = 0;

  function automatic logic bus_bit(input logic value);
    bus_bit = (value === 1'b0) ? 1'b0 : 1'b1;
  endfunction

  // START and STOP are transitions on SDA while SCL is high, so they never
  // land on the SCL edges that carry data.
  always @(negedge sda) if (scl === 1'b1) begin
    start_conditions++;
    state = ADDR;
    bit_index = 0;
    rx_shift = 8'h00;
    drive_low = 1'b0;
  end

  always @(posedge sda) if (scl === 1'b1 && state != IDLE) begin
    stop_conditions++;
    state = IDLE;
    drive_low = 1'b0;
  end

  always @(posedge scl) begin
    case (state)
      ADDR, RX: begin
        rx_shift = {rx_shift[6:0], bus_bit(sda)};
        bit_index++;
      end
      TX_ACK: master_ack = (sda === 1'b0);
      default: ;
    endcase
  end

  always @(negedge scl) begin
    case (state)
      ADDR: if (bit_index == 8) begin
        if (rx_shift[7:1] == ADDRESS) begin
          reading = rx_shift[0];
          drive_low = 1'b1;
          state = ADDR_ACK;
        end else begin
          state = SILENT;            // another slave's transaction
        end
      end

      ADDR_ACK: begin
        drive_low = 1'b0;
        bit_index = 0;
        if (reading) begin
          tx_byte = regs[pointer];
          pointer = (pointer + 1) % REGISTERS;
          drive_low = (tx_byte[7] === 1'b0);
          state = TX;
        end else begin
          pointer_written = 1'b0;
          state = RX;
        end
      end

      RX: if (bit_index == 8) begin
        if (!pointer_written) begin
          pointer = rx_shift % REGISTERS;
          pointer_written = 1'b1;
        end else begin
          regs[pointer] = rx_shift;
          pointer = (pointer + 1) % REGISTERS;
        end
        drive_low = 1'b1;
        state = RX_ACK;
      end

      RX_ACK: begin
        drive_low = 1'b0;
        bit_index = 0;
        state = RX;
      end

      TX: begin
        bit_index++;
        if (bit_index < 8) begin
          drive_low = (tx_byte[7-bit_index] === 1'b0);
        end else begin
          drive_low = 1'b0;          // release for the master's acknowledge
          state = TX_ACK;
        end
      end

      TX_ACK: begin
        bit_index = 0;
        if (master_ack) begin
          tx_byte = regs[pointer];
          pointer = (pointer + 1) % REGISTERS;
          drive_low = (tx_byte[7] === 1'b0);
          state = TX;
        end else begin
          state = SILENT;           // a refused byte ends the read
        end
      end

      default: ;
    endcase
  end
endmodule
