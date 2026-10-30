`timescale 1ns/1ps
// GENERATED SIMULATION MODEL ONLY
module RO_basic_delayed (
    input wire Enable,
    output wire RO_out
);

    wire RO_in;
    wire nand_out /* synthesis keep = 1 */;
    wire not_1 /* synthesis keep = 1 */;
    wire not_2 /* synthesis keep = 1 */;
    wire not_3 /* synthesis keep = 1 */;
    wire not_4 /* synthesis keep = 1 */;
    wire not_5 /* synthesis keep = 1 */;
    wire not_6 /* synthesis keep = 1 */;
    wire not_7 /* synthesis keep = 1 */;
    wire not_8 /* synthesis keep = 1 */;
    wire not_9 /* synthesis keep = 1 */;

    // Nine inversions in the feedback loop; not_9 is the output inverter.
    assign #1 nand_out = ~(Enable & RO_in);
    assign #1 not_1 = ~nand_out;
    assign #1 not_2 = ~not_1;
    assign #1 not_3 = ~not_2;
    assign #1 not_4 = ~not_3;
    assign #1 not_5 = ~not_4;
    assign #1 not_6 = ~not_5;
    assign #1 not_7 = ~not_6;
    assign #1 not_8 = ~not_7;
    assign #1 not_9 = ~not_8;

    assign RO_in = not_8;
    assign RO_out = not_9;

endmodule
