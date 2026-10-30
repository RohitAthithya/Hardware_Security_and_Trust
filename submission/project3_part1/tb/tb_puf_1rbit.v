`timescale 1ps/1ps

module tb_puf_1rbit();

localparam integer C_BITS_1BIT = 1;
localparam integer C_BITS_4BIT = 4;
localparam integer SETTLE_1BIT = 16*C_BITS_1BIT;
localparam integer SETTLE_4BIT = 16*C_BITS_4BIT;

// Each stage byte is {bottom mux delay, top mux delay}.
// Each mux nibble is {delay on b, delay on a}, with two bits per delay.
localparam [7:0] DELAY_1BIT = 8'h69;
localparam [31:0] DELAY_4BIT = 32'hDF66FFAD;

// Independently calculated responses; bit c is the response to challenge c.
// Challenge 0 through 15: 0,1,0,1,0,1,0,1,1,0,0,1,0,1,1,0.
// All final top/bottom arrival times are unequal for these configurations.
localparam [15:0] EXPECTED_4BIT = 16'h69AA;

reg reset_1bit;
reg enable_1bit;
reg [C_BITS_1BIT-1:0] challenge_1bit;
wire resp_1bit;

reg reset_4bit;
reg enable_4bit;
reg [C_BITS_4BIT-1:0] challenge_4bit;
wire resp_4bit;

integer checks;
integer failures;
integer sweep;
integer c;

puf_1rbit #(
    .C_BITS(C_BITS_1BIT),
    .DELAY(DELAY_1BIT)
) DUT_1BIT (
    .reset(reset_1bit),
    .enable(enable_1bit),
    .challenge(challenge_1bit),
    .resp(resp_1bit)
);

puf_1rbit #(
    .C_BITS(C_BITS_4BIT),
    .DELAY(DELAY_4BIT)
) DUT_4BIT (
    .reset(reset_4bit),
    .enable(enable_4bit),
    .challenge(challenge_4bit),
    .resp(resp_4bit)
);

// Packed text arguments keep this test bench compatible with Verilog.
task check_result;
    input [8*16-1:0] dut_name;
    input [3:0] challenge_value;
    input actual;
    input expected;
    input [8*64-1:0] test_name;
    begin
        checks = checks + 1;
        // Case inequality also flags unexpected X and Z values.
        if (actual !== expected) begin
            failures = failures + 1;
            $display("%0t FAIL %0s challenge=%b expected=%b actual=%b : %0s",
                     $time, dut_name, challenge_value, expected, actual, test_name);
        end
        else begin
            $display("%0t PASS %0s challenge=%b expected=%b actual=%b : %0s",
                     $time, dut_name, challenge_value, expected, actual, test_name);
        end
    end
endtask

task measure_1bit;
    input challenge_in;
    input expected;
    begin
        reset_1bit = 1'b1;
        enable_1bit = 1'b0;
        challenge_1bit = challenge_in;
        #(SETTLE_1BIT);
        check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b0,
                     "reset before measurement");

        reset_1bit = 1'b0;
        #1;
        enable_1bit = 1'b1;
        #(SETTLE_1BIT);
        check_result("DUT_1BIT", challenge_1bit, resp_1bit, expected,
                     "captured response");
    end
endtask

task measure_4bit;
    input [C_BITS_4BIT-1:0] challenge_in;
    begin
        reset_4bit = 1'b1;
        enable_4bit = 1'b0;
        challenge_4bit = challenge_in;
        #(SETTLE_4BIT);
        check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0,
                     "reset before measurement");

        reset_4bit = 1'b0;
        #1;
        enable_4bit = 1'b1;
        #(SETTLE_4BIT);
        check_result("DUT_4BIT", challenge_4bit, resp_4bit,
                     EXPECTED_4BIT[challenge_in], "captured response");
    end
endtask

initial begin
    $timeformat(-12, 0, " ps", 0);
    checks = 0;
    failures = 0;
    reset_1bit = 1'b0;
    enable_1bit = 1'b0;
    challenge_1bit = 1'b0;
    reset_4bit = 1'b0;
    enable_4bit = 1'b0;
    challenge_4bit = 4'b0000;

    $display("Testing puf_1rbit: one-stage and four-stage configurations");
    $display("Times are in ps; the one-stage challenge is displayed in 4 bits.");

    // Generate an explicit reset edge after simulation initialization.
    #1;
    reset_1bit = 1'b1;
    reset_4bit = 1'b1;
    #(SETTLE_4BIT);
    check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b0, "initial reset");
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0, "initial reset");

    reset_1bit = 1'b0;
    reset_4bit = 1'b0;
    #(SETTLE_4BIT);
    check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b0,
                 "idle with enable low");
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0,
                 "idle with enable low");

    // Challenge 0: bottom arrives at 1 ps, top at 2 ps. Capture 0.
    // Checking after both arrivals also verifies that the later data edge
    // does not overwrite the value captured by the bottom path's clock.
    measure_1bit(1'b0, 1'b0);

    // Challenge 1: top arrives at 1 ps, bottom at 2 ps. Capture 1.
    measure_1bit(1'b1, 1'b1);

    // A falling enable/clock must not clear the captured response.
    enable_1bit = 1'b0;
    #(SETTLE_1BIT);
    check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b1,
                 "response retained after enable falls");

    // Capture 1 again, then reset while both final paths remain high.
    // There is no clock edge at reset, so this checks asynchronous clearing.
    measure_1bit(1'b1, 1'b1);
    reset_1bit = 1'b1;
    #1;
    check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b0,
                 "asynchronous reset while enable and clock stay high");
    reset_1bit = 1'b0;
    #(SETTLE_1BIT);
    check_result("DUT_1BIT", challenge_1bit, resp_1bit, 1'b0,
                 "no recapture without a new clock edge");
    enable_1bit = 1'b0;

    // The second sweep repeats every CRP after resetting and settling.
    // Reference examples: 0000 -> top 10 ps, bottom 9 ps, response 0;
    //                     0001 -> top 8 ps, bottom 9 ps, response 1.
    for (sweep = 1; sweep <= 2; sweep = sweep + 1) begin
        $display("Four-stage challenge sweep %0d of 2", sweep);
        for (c = 0; c < 16; c = c + 1) begin
            measure_4bit(c[3:0]);
        end
    end

    enable_4bit = 1'b0;
    #(SETTLE_4BIT);

    if (failures == 0)
        $display("PASS: all %0d checks passed; 0 failures.", checks);
    else
        $display("FAIL: %0d of %0d checks failed.", failures, checks);

    // Match the supplied test benches and leave the GUI available for inspection.
    $stop;
end

endmodule
