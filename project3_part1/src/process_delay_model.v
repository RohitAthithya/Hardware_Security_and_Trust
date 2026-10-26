`timescale 1ps/1ps //remove the delays while synthesizing
module process_delay_model #(
    parameter DELAY = 10
) (
    input wire_in,
    output wire_out
);

assign #(DELAY) wire_out = wire_in;

endmodule
