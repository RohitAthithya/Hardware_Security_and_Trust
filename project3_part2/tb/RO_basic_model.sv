`timescale 1ns/1ps
// SIMULATION ONLY: do not add this model to the Quartus project.
// Controlled periods test counter integration, not physical RO frequency.
module RO_basic #(
    parameter realtime HALF_PERIOD = 1.0
) (
    input wire Enable,
    output wire RO_out
);
    reg phase = 0;
    always #(HALF_PERIOD) phase = ~phase;
    assign RO_out = Enable ? phase : 1'b0;
endmodule
