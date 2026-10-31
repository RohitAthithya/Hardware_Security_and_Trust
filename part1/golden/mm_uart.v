/** @module : mm_uart
 *  @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
 *  Copyright (c) 2022 (STAM/SCAI/ASU)
 */

module mm_uart #(
  parameter DATA_WIDTH      = 8,
  parameter ADDR_WIDTH      = 8,
  parameter ADDR_BASE       = 32'd0,
  parameter UART_FIFO_SIZE  = 8,
  parameter UART_TXDATA_OFFSET = 8'h00,
  parameter UART_RXDATA_OFFSET = 8'h04
) (

  input clock,
  input reset,

  // UART Rx/Tx
  input uart_rx,
  output uart_tx,

  // Memory Mapped Port
  input  readEnable,
  input  writeEnable,
  input  [DATA_WIDTH/8-1:0] writeByteEnable,
  input  [ADDR_WIDTH-1:0] address,
  input  [DATA_WIDTH-1:0] writeData,
  output reg [DATA_WIDTH-1:0] readData,
  output ready

);

localparam BYTES_PER_WORD = DATA_WIDTH/8;

localparam UART_TXDATA_ADDR   = ADDR_BASE + UART_TXDATA_OFFSET;
localparam UART_RXDATA_ADDR   = ADDR_BASE + UART_RXDATA_OFFSET;

// Compute shifting values for each register. 32-bit and 64-bit DATA_WIDTHs
// must be supported but we dont want to read multiple registers in a single
// operation. Software should only use lw or smaller operations.
localparam TXDATA_SHIFT = 8*(UART_TXDATA_ADDR % BYTES_PER_WORD);
localparam RXDATA_SHIFT = 8*(UART_RXDATA_ADDR % BYTES_PER_WORD);

//define the log2 function
function integer log2;
  input integer num;
  integer i, result;
  begin
    for (i = 0; 2 ** i < num; i = i + 1)
      result = i + 1;
    log2 = result;
  end
endfunction

reg        tx_fifo_rd_en;
wire       tx_fifo_empty;
wire       tx_fifo_full;
wire       tx_fifo_valid;
wire       tx_fifo_wr_en;
wire [7:0] tx_fifo_read_data;

// Rx Show-Ahead FIFO

wire       rx_fifo_rd_en;
wire       rx_fifo_empty;
wire       rx_fifo_full;
wire       rx_fifo_valid;
wire       rx_fifo_wr_en;
wire [7:0] rx_fifo_read_data;
wire [7:0] rx_fifo_write_data;

wire [log2(UART_FIFO_SIZE):0] rx_cnt;
wire [log2(UART_FIFO_SIZE):0] tx_cnt;

wire        rxdata_fifo_empty = ~(|rx_cnt);

wire [31:0] reg_txdata = {tx_fifo_full , 23'h0, 8'd0};
wire [31:0] reg_rxdata = {rxdata_fifo_empty, 23'd0, {8{rx_fifo_valid}} & rx_fifo_read_data };

// UART Tx
wire tx_busy;

assign tx_fifo_wr_en = (address == UART_TXDATA_ADDR) & writeEnable & writeByteEnable[0] & ~tx_fifo_full;
assign rx_fifo_rd_en = (address == UART_RXDATA_ADDR) & readEnable;

assign ready = ~tx_fifo_full;


always@(posedge clock) begin
  if(reset)
    readData <= {DATA_WIDTH{1'b0}};
  else if(writeEnable)
    readData <= {DATA_WIDTH{1'b0}};
  else if(readEnable) begin
    case (address)
      UART_TXDATA_ADDR  : readData <= reg_txdata << TXDATA_SHIFT;
      UART_RXDATA_ADDR  : readData <= reg_rxdata << RXDATA_SHIFT;
      default           : readData <= {DATA_WIDTH{1'b0}};
    endcase
  end
  else
    readData <= {DATA_WIDTH{1'b0}};
end


always@(posedge clock) begin
  if(reset) begin
    tx_fifo_rd_en <= 1'b0;
  end
  else if(tx_fifo_rd_en) begin
    // Do not read two cycles in a row
    tx_fifo_rd_en <= 1'b0;
  end
  else begin
    tx_fifo_rd_en <= ~tx_fifo_empty & ~tx_busy;
  end
end

fifo #(
  .DATA_WIDTH(8),
  .Q_DEPTH_BITS(log2(UART_FIFO_SIZE)),
  .Q_IN_BUFFERS(0)
) TX_FIFO (
  .clk(clock),
  .reset(reset),
  .write_data(writeData[7:0]),
  .wrtEn(tx_fifo_wr_en),
  .rdEn(tx_fifo_rd_en),
  .peek(1'b0),

  .read_data(tx_fifo_read_data),
  .valid(tx_fifo_valid),
  .full(tx_fifo_full),
  .empty(tx_fifo_empty),
  .size(tx_cnt)
);

fifo #(
  .DATA_WIDTH(8),
  .Q_DEPTH_BITS(log2(UART_FIFO_SIZE)),
  .Q_IN_BUFFERS(0)
) RX_FIFO (
  .clk(clock),
  .reset(reset),
  .write_data(rx_fifo_write_data),
  .wrtEn(rx_fifo_wr_en),
  .rdEn(rx_fifo_rd_en),
  .peek(1'b0),

  .read_data(rx_fifo_read_data),
  .valid(rx_fifo_valid), // Unused
  .full(rx_fifo_full), // Unused
  .empty(rx_fifo_empty),
  .size(rx_cnt)
);

uart_rx RX (
  .clock(clock),
  .reset(reset),
  .serial_rx(uart_rx),
  .rx_valid(rx_fifo_wr_en),
  .rx_data(rx_fifo_write_data)
);

uart_tx TX (
  .clock(clock),
  .reset(reset),
  .tx_valid(tx_fifo_valid),
  .tx_data_in(tx_fifo_read_data),
  .serial_tx(uart_tx),
  .tx_busy(tx_busy)
);


always@(posedge clock) begin
  if(tx_fifo_wr_en) begin
    $write("%s", writeData[7:0]);
  end
end

endmodule
