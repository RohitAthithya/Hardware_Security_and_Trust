module PUF (
    input wire reset,
    input wire [3:0] Cha0,
    input wire [3:0] Cha1,
    output wire [3:0] Response,
    output wire [3:0] Invalid,
    output wire Done
);

    wire [63:0] RO_out;
    wire [3:0] group_done;

    // Preserve the original instance names for reproducible RO placement.
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin: gen_Ro
            RO_basic ro_inst (
                .Enable(~reset),
                .RO_out(RO_out[i])
            );
        end
    endgenerate

    Counter_group cg0 (
        .reset(reset),
        .Cha0(Cha0),
        .Cha1(Cha1),
        .RO_out(RO_out[15:0]),
        .Response(Response[0]),
        .Done(group_done[0]),
        .Invalid(Invalid[0])
    );

    Counter_group cg1 (
        .reset(reset),
        .Cha0(Cha0),
        .Cha1(Cha1),
        .RO_out(RO_out[31:16]),
        .Response(Response[1]),
        .Done(group_done[1]),
        .Invalid(Invalid[1])
    );

    Counter_group cg2 (
        .reset(reset),
        .Cha0(Cha0),
        .Cha1(Cha1),
        .RO_out(RO_out[47:32]),
        .Response(Response[2]),
        .Done(group_done[2]),
        .Invalid(Invalid[2])
    );

    Counter_group cg3 (
        .reset(reset),
        .Cha0(Cha0),
        .Cha1(Cha1),
        .RO_out(RO_out[63:48]),
        .Response(Response[3]),
        .Done(group_done[3]),
        .Invalid(Invalid[3])
    );

    assign Done = &group_done;

endmodule
