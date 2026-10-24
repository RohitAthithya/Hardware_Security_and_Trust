module tb_arbiter_puf();

parameter C_BITS = /*<FIXME>*/;
parameter R_BITS = /*<FIXME>*/;


`include delay_params.v

reg               reset;
reg               enable;
reg  [C_BITS-1:0] challenge;
wire [R_BITS-1:0] resp;

integer i;

arbiter_puf #(
  .C_BITS(C_BITS),
  .R_BITS(R_BITS),
  .DELAY(DELAY)
) DUT_A (
  .reset(reset),
  .enable(enable),
  .challenge(challenge),
  .resp(resp)
);

// Query the PUF with a challenge input, display the response output.
task gen_crp;
input [C_BITS-1:0] challenge_in;
begin
  reset = 1'b0;
  enable = 1'b0;
  // Set the given challenge input signals
  challenge = challenge_in;

  #10
  // Reset the PUF
  reset = 1'b1;
  #10
  // Lower the reset signal to exit reset
  reset = 1'b0;
  #10
  // Enable the PUF to receive a response
  enable = 1'b1;


  // Wait  for longest possible delay
  #(16*C_BITS)

  // Print the Challenge, Response Pair
  $display("Challenge: %b, Response: %b", challenge, resp);
  // Lower the enable signal once the response has been received
  enable = 1'b0;
end
endtask


initial begin

  // Generate responses for challenges 0-3
  gen_crp(0);
  gen_crp(1);
  gen_crp(2);
  gen_crp(3);

//-----------------------------------------------------------------------------
// Add more test cases here.
//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
  $stop;
end

endmodule
