module arbiter_puf #(
  parameter C_BITS = 4, // Challenge Bits
  parameter R_BITS = 4, // Response Bits
  parameter [2*4*C_BITS*R_BITS-1:0] DELAY = 4'd12 // Random Delay Values
) (
  input               reset,     // Active-high reset to set all registers to 0
  input               enable,    // Enable the PUF circuit
  input  [C_BITS-1:0] challenge, // The PUF challenge input
  output [R_BITS-1:0] resp       // The PUF response output
);

//-----------------------------------------------------------------------------
// Your Code Here.
//-----------------------------------------------------------------------------








//-----------------------------------------------------------------------------
endmodule
