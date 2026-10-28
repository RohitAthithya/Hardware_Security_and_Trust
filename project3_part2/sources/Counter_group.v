module Counter_group (
  input reset,
  input [3:0] Cha0,
  input [3:0] Cha1,
  input [15:0] RO_out,
  output Response
);

reg count_val0, count_val1; 
reg [15:0] count_num0 , count_num1;
reg resp0,resp1;
//----------------------------------------------------------------------------
// Your Logic Here
//----------------------------------------------------------------------------


assign Response = resp0;

always@(*)

begin
 case(Cha0)
 4'b0000:count_val0 =  RO_out[4'h0];
 4'b0001:count_val0 =  RO_out[4'h1];
 4'b0010:count_val0 =  RO_out[4'h2]; 
 4'b0011:count_val0 =  RO_out[4'h3]; 
 4'b0100:count_val0 =  RO_out[4'h4]; 
 4'b0101:count_val0 =  RO_out[4'h5]; 
 4'b0110:count_val0 =  RO_out[4'h6]; 
 4'b0111:count_val0 =  RO_out[4'h7]; 
 4'b1000:count_val0 =  RO_out[4'h8]; 
 4'b1001:count_val0 =  RO_out[4'h9]; 
 4'b1010:count_val0 =  RO_out[4'ha]; 
 4'b1011:count_val0 =  RO_out[4'hb]; 
 4'b1100:count_val0 =  RO_out[4'hc]; 
 4'b1101:count_val0 =  RO_out[4'hd]; 
 4'b1110:count_val0 =  RO_out[4'he]; 
 4'b1111:count_val0 =  RO_out[4'hf]; 
 default:count_val0 =  RO_out[4'h0]; 
 endcase

 case(Cha1)
 4'b0000:count_val1 =  RO_out[4'h0];
 4'b0001:count_val1 =  RO_out[4'h1];
 4'b0010:count_val1 =  RO_out[4'h2]; 
 4'b0011:count_val1 =  RO_out[4'h3]; 
 4'b0100:count_val1 =  RO_out[4'h4]; 
 4'b0101:count_val1 =  RO_out[4'h5]; 
 4'b0110:count_val1 =  RO_out[4'h6]; 
 4'b0111:count_val1 =  RO_out[4'h7]; 
 4'b1000:count_val1 =  RO_out[4'h8]; 
 4'b1001:count_val1 =  RO_out[4'h9]; 
 4'b1010:count_val1 =  RO_out[4'ha]; 
 4'b1011:count_val1 =  RO_out[4'hb]; 
 4'b1100:count_val1 =  RO_out[4'hc]; 
 4'b1101:count_val1 =  RO_out[4'hd]; 
 4'b1110:count_val1 =  RO_out[4'he]; 
 4'b1111:count_val1 =  RO_out[4'hf]; 
 default:count_val1 =  RO_out[4'hf];
 endcase

end

always@(posedge count_val0 or posedge reset )
begin
if (reset)
begin
count_num0 <= {16{1'b0}};
resp0 <= 1'b0;
end

else
begin
  count_num0 <= count_num0 + 16'd1;
  if (count_num0 == 16'd65534 && !resp1)
    resp0 <= 1'b1;
end

end



always@(posedge count_val1 or posedge reset )
begin
if (reset)
begin
count_num1 <= {16{1'b0}};
resp1 <= 1'b0;
end

else
begin
  count_num1 <= count_num1 + 16'd1;
  if (count_num1 == 16'd65534)
    resp1 <= 1'b1;
end

end



//----------------------------------------------------------------------------

endmodule
