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


assign nand_out = ~ (Enable & RO_in);
assign not_1  = ~ nand_out;
assign RO_in  = ~not_1;
assign RO_out = RO_in;



//----------------------------------------------------------------------------
endmodule
