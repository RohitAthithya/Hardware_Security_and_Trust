module RO_basic (
  input Enable,
  output RO_out
);
//----------------------------------------------------------------------------
// Your Logic Here
//----------------------------------------------------------------------------

wire RO_in;
wire nand_out;
wire not_1;
wire not_2;
wire not_3;
wire not_4;
wire not_5;
wire not_6;
wire not_7;
wire not_8;
wire not_9;


assign nand_out = ~ (Enable & RO_in);
assign not_1  = ~ nand_out;
assign not_2  = ~ not_1;
assign not_3 = ~ not_2;
assign not_4 = ~not_3;
assign not_5 = ~not_4;
assign not_6 = ~not_5;
assign not_7 = ~not_6;
assign not_8 = ~not_7;
assign not_9 = ~not_8;


assign RO_in  = not_8;
assign RO_out = not_9;



//----------------------------------------------------------------------------
endmodule
