module puf_1rbit #(
    parameter C_BITS = 4,
    parameter DELAY_BITS = 2*4*C_BITS,
    parameter [DELAY_BITS-1:0] DELAY = 32
)(
    //outputs
    output              resp,       // The PUF response output
    
    input               reset,     // Active-high reset to set all registers to 0
    input               enable,    // Enable the PUF circuit
    input  [C_BITS-1:0] challenge // The PUF challenge input
);

wire [C_BITS-1+1:0] mux_output_top;
wire [C_BITS-1+1:0] mux_output_btm;

assign mux_output_top[C_BITS-1+1] = enable;
assign mux_output_btm[C_BITS-1+1] = enable;


genvar i;
generate
    for (i=C_BITS; i > 0; i = i - 1) begin
        mux #(
            .DELAY(DELAY[8*(i-1)+: 4])
        ) mux_top (
            .out(mux_output_top[i-1]),
            .b(mux_output_btm[i]),
            .a(mux_output_top[i]),
            .sel(challenge[i-1])
        );
        mux #(
            .DELAY(DELAY[8*(i-1)+4 +: 4])
        ) mux_bottom (
            .out(mux_output_btm[i-1]),
            .b(mux_output_top[i]),
            .a(mux_output_btm[i]),
            .sel(challenge[i-1])
        );
    end

endgenerate

d_ff out_reg(
    .q(resp),

    .d(mux_output_top[0]),
    .clk(mux_output_btm[0]),
    .reset(reset)
);





endmodule