`timescale 1ps/1ps

module tb_harvest_crp();
parameter C_BITS = 4;
parameter R_BITS = 32;

`include "delay_params.v"

reg reset;
reg enable;
reg [C_BITS-1:0] challenge;
wire [R_BITS-1:0] resp;
integer i;

arbiter_puf #(
    .C_BITS(C_BITS),
    .R_BITS(R_BITS),
    .DELAY(DELAY)
) DUT (
    .reset(reset),
    .enable(enable),
    .challenge(challenge),
    .resp(resp)
);

initial begin
    reset = 1'b1;
    enable = 1'b0;
    challenge = {C_BITS{1'b0}};
    #(16*C_BITS);

    for (i = 0; i < (1 << C_BITS); i = i + 1) begin
        enable = 1'b0;
        reset = 1'b1;
        challenge = i;
        // Let both paths settle low before launching the next race.
        #(16*C_BITS);
        reset = 1'b0;
        #10;
        enable = 1'b1;
        #(16*C_BITS);
        $display("Challenge: %b, Response: %b", challenge, resp);
        enable = 1'b0;
    end

    $finish;
end
endmodule
