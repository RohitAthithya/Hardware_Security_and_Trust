/** @module : tb_netlist_C
 *  @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
 *  Copyright (c) 2022 (STAM/SCAI/ASU)
 */

module tb_netlist_C();

localparam DATA_WIDTH         = 8;
localparam ADDR_WIDTH         = 8;
localparam UART_TXDATA_ADDR   = 8'd0;
localparam UART_RXDATA_ADDR   = 8'd4;

reg clock;
reg clock_baud;
reg reset;

// UART Rx/Tx
reg  uart_rx;
wire uart_tx;

// Memory Mapped Port
reg  readEnable;
reg  writeEnable;
reg  [DATA_WIDTH/8-1:0] writeByteEnable;
reg  [ADDR_WIDTH-1:0] address;
reg  [DATA_WIDTH-1:0] writeData;
wire [DATA_WIDTH-1:0] readData;
wire                  ready;

//Loopback tx --> rx
//assign uart_rx = uart_tx;

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

mm_uart DUT (
  .clock         (clock),
  .reset         (reset),
  .uart_rx       (uart_rx),
  .uart_tx       (uart_tx),
  // Memory Mapped Port
  .readEnable     (readEnable),
  .writeEnable    (writeEnable),
  .writeByteEnable(writeByteEnable),
  .address        (address),
  .writeData      (writeData),
  .readData       (readData),
  .ready           (ready)
);

//-----------------------------------------------------------//
//
// Tasks
//
//-----------------------------------------------------------//

// initialization task

task initialize;
begin
  $display("INITIALIZING...");
  clock = 1'b1;
  clock_baud =1'b1;
  uart_rx = 1'b1;
  reset = 1'b1;
  readEnable      = 1'b0;
  writeEnable     = 1'b0;
  writeByteEnable = 4'h0;
  address         = 32'h0;
  writeData       = 32'h0;

  repeat (3) @ (posedge clock);
  reset = 1'b0;
end
endtask

// register write task

task reg_write;
  input [31:0] addr;
  input [3:0]  wbe;
  input [31:0] wrdata;

  begin
    repeat (1) @ (posedge clock);
    $display(" REG WRITE -- ADDR=%08h at %tns" ,addr, $time);
    readEnable      = 1'h0;
    writeEnable     = 1'h1;
    writeByteEnable = wbe;
    writeData       = wrdata;
    address         = addr ;
  end
endtask

// register read task

task reg_read;
  input [31:0] addr;

  begin
    repeat (1) @ (posedge clock);
    $display(" REG READ --- ADDR=%08h at %tns" ,addr, $time);
    readEnable      = 1'h1;
    writeEnable     = 1'h0;
    writeByteEnable = 4'h0;
    address         = addr ;
    repeat (1) @ (posedge clock);
    #1
    $display("          --- DATA=%08h at %tns",readData, $time);
  end
endtask

task delay;
  input integer number;
  begin
    repeat (number) @ (posedge clock);
  end
endtask

task inactive;
  input integer number;
  begin
    readEnable      = 1'h0;
    writeEnable     = 1'h0;
    writeByteEnable = 4'h0;
    address         =32'h0 ;
    delay(number);
  end
endtask
//-----------------------------------------------------------//
//
// Simulation
//
//-----------------------------------------------------------//

//100MHz CLK
always #5 clock = ~clock;
always #50 clock_baud = ~clock_baud;

initial begin
  initialize;
  inactive(10);

  //-----------------------------------------------------------//
  // Write your test code here.
  //-----------------------------------------------------------//










  //-----------------------------------------------------------//
end



endmodule
