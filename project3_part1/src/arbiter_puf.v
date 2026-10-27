module arbiter_puf #(
  parameter C_BITS = 4, // Challenge Bits
  parameter R_BITS = 32, // Response Bits
  parameter [2*4*C_BITS*R_BITS-1:0] DELAY = 4'd12 // Random Delay Values
) (
  input               reset,     // Active-high reset to set all registers to 0
  input               enable,    // Enable the PUF circuit
  input  [C_BITS-1:0] challenge, // The PUF challenge input
  output [R_BITS-1:0] resp       // The PUF response output
);

// Each response bit uses two 4-bit mux delays per challenge bit.
localparam DELAY_BITS_PER_RESPONSE = 2 * 4 * C_BITS;

genvar i;
generate
  for (i = 0; i < R_BITS; i = i + 1) begin : gen_puf
    puf_1rbit #(
      .C_BIT(C_BITS),
      .DELAY(DELAY[i*DELAY_BITS_PER_RESPONSE +: DELAY_BITS_PER_RESPONSE])
    ) puf_inst (
      .resp(resp[i]),
      .reset(reset),
      .enable(enable),
      .challenge(challenge)
    );
  end
endgenerate

endmodule
