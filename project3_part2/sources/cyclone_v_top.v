module cyclone_v_top (
    input wire CLOCK_50_B5B,
    input wire CLOCK_50_B6A,
    input wire CLOCK_50_B7A,
    input wire CLOCK_50_B8A,
    input wire CPU_RESET_n,
    input wire [3:0] KEY,
    output wire [7:0] LEDG,
    output wire [9:0] LEDR,
    input wire [9:0] SW
);

    wire [3:0] response;
    wire [3:0] invalid;
    wire done;

    // KEY0 is active low. Board clocks are intentionally unused.
    PUF puf_inst (
        .reset(~KEY[0]),
        .Cha0(SW[3:0]),
        .Cha1(SW[7:4]),
        .Response(response),
        .Invalid(invalid),
        .Done(done)
    );

    assign LEDG = {3'b000, done, response};
    assign LEDR = {6'b000000, invalid};

endmodule
