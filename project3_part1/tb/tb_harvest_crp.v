module tb_harvest_crp();
//-----------------------------------------------------------------------------
// Your Code Here
//-----------------------------------------------------------------------------
reg reset;
reg enable;
reg [C_BITS-1:0] challenge;
wire [R_BITS-1:0] resp;

`include "delay_params.v"
parameter C_BITS = 4;
parameter R_BITS = 32;

arbiter_puf #(
   C_BITS(C_BITS), // Challenge Bits
   R_BITS(R_BITS), // Response Bits
   .DELAY(DELAY)
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
    for(i = 0; i <15; i++)
    begin
        $display("the value of the response: %d for the challenge: %d",response,challenge);
      #5  challenge = challenge + 1'b1;
    end


end



//-----------------------------------------------------------------------------
endmodule
