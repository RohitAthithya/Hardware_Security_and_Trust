module cyclone_v_top (
  ///////// CLOCK /////////
  input              CLOCK_50_B5B,
  input              CLOCK_50_B6A,
  input              CLOCK_50_B7A,
  input              CLOCK_50_B8A,

  ///////// CPU /////////
  input              CPU_RESET_n,

  ///////// KEY /////////
  input       [3:0]  KEY,

  ///////// LEDG /////////
  output      [7:0]  LEDG,

  ///////// LEDR /////////
  output      [9:0]  LEDR,

  ///////// SW /////////
  input       [9:0]  SW,

  ///////// UART /////////
  input              UART_RX,
  output             UART_TX

);

cove_processor #(
  .CORE(0),
  .CLOCK_FREQUENCY(50000000), // 50MHz
  .BAUD_RATE(115200),
  .DATA_WIDTH(64),
  .ADDRESS_BITS(64),
  .MEM_ADDRESS_BITS(15),

  .UART_FIFO_SIZE(1024),
  .INIT_FILE_BASE("uart_example.vmh")
) COVE (
  .clock(CLOCK_50_B5B),
  .reset(~KEY[0]),

  .start(1'b0), // Unused
  .program_address(64'd0), // Unused

  // Interrupts
  .m_ext_interrupt(1'b0), // Unused
  .s_ext_interrupt(1'b0), // Unused

  .PC(), // Unused

  .uart_rx(UART_RX),
  .uart_tx(UART_TX),

  .scan(1'b0) // Unused
);



endmodule
