module RO_basic (
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
    assign nand_out = ~(Enable & RO_in);
    assign not_1 = ~nand_out;
    assign not_2 = ~not_1;
    assign not_3 = ~not_2;
    assign not_4 = ~not_3;
    assign not_5 = ~not_4;
    assign not_6 = ~not_5;
    assign not_7 = ~not_6;
    assign not_8 = ~not_7;
    assign not_9 = ~not_8;

    assign RO_in = not_8;
    assign RO_out = not_9;

endmodule
