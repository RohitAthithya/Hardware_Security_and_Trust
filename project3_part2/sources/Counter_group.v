module Counter_group (
    output wire Response,
    output wire Done,
    output wire Invalid,
    input wire reset,
    input wire [3:0] Cha0,
    input wire [3:0] Cha1,
    input wire [15:0] RO_out
);

    wire clk0 /* synthesis keep = 1 */;
    wire clk1 /* synthesis keep = 1 */;
    wire [15:0] count0;
    wire [15:0] count1;
    wire done0;
    wire done1;

    // Challenges stay fixed from reset release until completion.
    assign clk0 = RO_out[Cha0] & ~done1;
    assign clk1 = RO_out[Cha1] & ~done0;

    ro_counter #(.W(16)) counter0 (
        .ro_clk(clk0),
        .reset(reset),
        .count(count0),
        .done(done0)
    );

    ro_counter #(.W(16)) counter1 (
        .ro_clk(clk1),
        .reset(reset),
        .count(count1),
        .done(done1)
    );

    // Read after Done and settling; discard Response whenever Invalid is high.
    assign Done = done0 | done1;
    assign Invalid = Done && (count0 == count1);
    assign Response = done1;

endmodule
