module puf_1rbit #(
    parameter C_BIT = 4,
    parameter [2*4*C_BITS-1:0] DELAY = 32
) (
    //outputs
    output              resp,       // The PUF response output
    
    input               reset,     // Active-high reset to set all registers to 0
    input               enable,    // Enable the PUF circuit
    input  [C_BITS-1:0] challenge // The PUF challenge input
);



endmodule