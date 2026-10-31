/** @module : uart_tx
 *  @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
 *  Copyright (c) 2022 (STAM/SCAI/ASU)
 */

module uart_tx (
  input clock,
  input reset,
  input tx_valid,
  input [7:0] tx_data_in,
  //output reg serial_tx,
  output serial_tx,
  output reg tx_busy
);

//localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY/BAUD_RATE;

localparam IDLE = 4'h9;
localparam START_BIT = 4'hA;
localparam BIT0 = 4'h0;
localparam BIT1 = 4'h1;
localparam BIT2 = 4'h2;
localparam BIT3 = 4'h3;
localparam BIT4 = 4'h4;
localparam BIT5 = 4'h5;
localparam BIT6 = 4'h6;
localparam BIT7 = 4'h7;
localparam STOP_BIT = 4'h8;

reg [3:0]  state;
reg [7:0]  tx_data;
reg [15:0] count;

reg serial_tx_r1;
reg serial_tx_r2;

wire [15:0] div;
assign div = 16'd10;

/* This seems to fix the garbage byte that startix V sends on configuration
* but this also reduces FMAX from ~60-70MHz to just 50Mhz.
initial begin
  serial_tx <= 1'b1;
  serial_tx_r1 <= 1'b1;
  serial_tx_r2 <= 1'b1;
end
*/

assign serial_tx = ~serial_tx_r2;
always@(posedge clock) begin
  if(reset) begin
    //serial_tx    <= 1'b1;
    serial_tx_r2 <= 1'b0;
  end
  else begin
    //serial_tx    <= serial_tx_r2;
    serial_tx_r2 <= serial_tx_r1;
  end
end

always@(posedge clock) begin
  if(reset) begin
    state     <= IDLE;
    count     <= 16'd0;
    tx_busy   <= 1'b0;
    tx_data   <= 8'd0;
    serial_tx_r1 <= 1'b1;
  end else begin
    case(state)
      IDLE: begin
        state <= tx_valid ? START_BIT : IDLE;
        count     <= 16'd0;
        tx_busy <= tx_valid;
        //tx_data <= tx_data_in;
        ///serial_tx_r1 <= 1'b1;
        // Invert data so it can be inverted again on serial_tx
        tx_data <= ~tx_data_in;
        serial_tx_r1 <= 1'b0;
      end
      START_BIT: begin
        if(count == div-1) begin
          state <= BIT0;
          count <= 16'd0;
        end
        else begin
          state <= START_BIT;
          count <= count + 16'd1;
        end
        //serial_tx_r1 <= 1'b0;
        serial_tx_r1 <= 1'b1;
      end
      BIT0: begin
        if(count == div-1) begin
          state <= BIT1;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT0;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT1: begin
        if(count == div-1) begin
          state <= BIT2;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT1;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT2: begin
        if(count == div-1) begin
          state <= BIT3;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT2;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT3: begin
        if(count == div-1) begin
          state <= BIT4;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT3;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT4: begin
        if(count == div-1) begin
          state <= BIT5;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT4;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT5: begin
        if(count == div-1) begin
          state <= BIT6;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT5;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT6: begin
        if(count == div-1) begin
          state <= BIT7;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT6;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      BIT7: begin
        if(count == div-1) begin
          state <= STOP_BIT;
          count <= 16'd0;
          tx_data <= {1'b0, tx_data[7:1]};
        end
        else begin
          state <= BIT7;
          count <= count + 16'd1;
          tx_data <= tx_data;
        end
        serial_tx_r1 <= tx_data[0];
      end
      STOP_BIT: begin
        if(count == div-1) begin
          state <= IDLE;
          count <= 16'd0;
        end
        else begin
          state <= STOP_BIT;
          count <= count + 16'd1;
        end
        //serial_tx_r1 <= 1'b1;
        serial_tx_r1 <= 1'b0;
      end
      default: begin
        state <= state;
        serial_tx_r1 <= 1'b0;
        tx_busy <= 1'b1;
      end
    endcase
  end
end

endmodule
