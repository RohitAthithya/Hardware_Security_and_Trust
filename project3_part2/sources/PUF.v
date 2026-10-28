module PUF (
  input        reset,
  input  [3:0] Cha0,
  input  [3:0] Cha1,
  output [3:0] Response
);
//----------------------------------------------------------------------------
// Your Logic Here
//----------------------------------------------------------------------------
wire [63:0]RO_out;

genvar i;
generate
for(i=0; i<64; i++)
begin: gen_Ro
  RO_basic ro_inst(
   .Enable(~reset),
   .RO_out(RO_out[i])
    );
end
endgenerate



Counter_group cg0(
.reset(reset),
.Cha0(Cha0),
.Cha1(Cha1),
.RO_out(RO_out[15:0]),
.Response(Response[0])
);

Counter_group cg1(
.reset(reset),
.Cha0(Cha0),
.Cha1(Cha1),
.RO_out(RO_out[31:16]),
.Response(Response[1])
);

Counter_group cg2(
.reset(reset),
.Cha0(Cha0),
.Cha1(Cha1),
.RO_out(RO_out[47:32]),
.Response(Response[2])
);


Counter_group cg3(
.reset(reset),
.Cha0(Cha0),
.Cha1(Cha1),
.RO_out(RO_out[63:48]),
.Response(Response[3])
);

//----------------------------------------------------------------------------
endmodule
