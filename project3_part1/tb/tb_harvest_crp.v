module tb_harvest_crp();
//-----------------------------------------------------------------------------
// Your Code Here
//-----------------------------------------------------------------------------
reg reset;
reg enable;
reg [C_BITS-1:0] challenge;
wire [R_BITS-1:0] resp;

arbiter_puf #(
   C_BITS = 4, // Challenge Bits
   R_BITS = 32, // Response Bits
   DELAY = 4'd12 // Random Delay Values
) (
    .reset(reset),     
    .enable(enable),   
    .challenge(challenge), 
    .resp(resp)       
);
int i;
initial 
begin
    enable = 1;
    reset = 1'b1;

    #5
    reset = 1'b0;

   #5
   challenge = 4'b0000;
    for(i = 0; i <16; i++)
    begin
      #5  challenge = challenge + 1'b1;
    end


end












//-----------------------------------------------------------------------------
endmodule
