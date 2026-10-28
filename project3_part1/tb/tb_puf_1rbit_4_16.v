`timescale 1ps/1ps

module tb_puf_1rbit_4_16();

localparam SETTLE_4BIT = 16*4;
localparam SETTLE_16BIT = 16*16;
localparam [31:0] DELAY_4BIT = 32'hDF66FFAD;
localparam [127:0] DELAY_16BIT = 128'hDB99567DA7F6F57F67AA59B665D7FAD7;

// Independently calculated responses; these do not learn answers from the DUT.
// Four-bit table index is the challenge value. Sixteen-bit table index is the
// directed case number returned by challenge_16_case, not the challenge value.
// All tested final top/bottom arrival times are unequal.
localparam [15:0] EXPECTED_4BIT = 16'h69AA;
localparam [43:0] EXPECTED_16BIT = 44'hDCFE01FFFF8;

reg reset_4bit;
reg enable_4bit;
reg [3:0] challenge_4bit;
wire resp_4bit;
reg reset_16bit;
reg enable_16bit;
reg [15:0] challenge_16bit;
wire resp_16bit;
integer checks;
integer failures;
integer sweep;
integer c;

puf_1rbit #(.C_BITS(4), .DELAY(DELAY_4BIT)) DUT_4BIT (
    .reset(reset_4bit), .enable(enable_4bit),
    .challenge(challenge_4bit), .resp(resp_4bit)
);
puf_1rbit #(.C_BITS(16), .DELAY(DELAY_16BIT)) DUT_16BIT (
    .reset(reset_16bit), .enable(enable_16bit),
    .challenge(challenge_16bit), .resp(resp_16bit)
);

// 44 distinct cases: all-zero/all-one, alternating patterns, a walking 1 and
// walking 0 at every bit position, four blocks, and four mixed patterns.
// This is a directed sample of the 65,536 possible sixteen-bit challenges.
function [15:0] challenge_16_case;
    input integer index;
    begin
        if (index >= 4 && index < 20)
            challenge_16_case = 16'h0001 << (index-4);
        else if (index >= 20 && index < 36)
            challenge_16_case = 16'hFFFF ^ (16'h0001 << (index-20));
        else begin
            case (index)
                0: challenge_16_case = 16'h0000;
                1: challenge_16_case = 16'hFFFF;
                2: challenge_16_case = 16'hAAAA;
                3: challenge_16_case = 16'h5555;
                36: challenge_16_case = 16'h000F;
                37: challenge_16_case = 16'h00F0;
                38: challenge_16_case = 16'h0F00;
                39: challenge_16_case = 16'hF000;
                40: challenge_16_case = 16'h1234;
                41: challenge_16_case = 16'h5678;
                42: challenge_16_case = 16'h9ABC;
                43: challenge_16_case = 16'hDEAD;
                default: challenge_16_case = 16'hxxxx;
            endcase
        end
    end
endfunction

task check_result;
    input [8*16-1:0] dut_name;
    input [15:0] challenge_value;
    input actual;
    input expected;
    input [8*64-1:0] test_name;
    begin
        checks = checks + 1;
        if (actual !== expected) begin
            failures = failures + 1;
            $display("%0t FAIL %0s challenge=%016b expected=%b actual=%b : %0s",
                     $time, dut_name, challenge_value, expected, actual, test_name);
        end
        else
            $display("%0t PASS %0s challenge=%016b expected=%b actual=%b : %0s",
                     $time, dut_name, challenge_value, expected, actual, test_name);
    end
endtask

task measure_4bit;
    input [3:0] challenge_in;
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

task measure_16bit;
    input integer case_index;
    begin
        reset_16bit = 1'b1;
        enable_16bit = 1'b0;
        challenge_16bit = challenge_16_case(case_index);
        #(SETTLE_16BIT);
        check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b0,
                     "reset before measurement");
        reset_16bit = 1'b0;
        #1;
        enable_16bit = 1'b1;
        #(SETTLE_16BIT);
        check_result("DUT_16BIT", challenge_16bit, resp_16bit,
                     EXPECTED_16BIT[case_index], "captured response");
    end
endtask

initial begin
    $timeformat(-12, 0, " ps", 0);
    checks = 0;
    failures = 0;
    reset_4bit = 1'b0;
    enable_4bit = 1'b0;
    challenge_4bit = 4'b0;
    reset_16bit = 1'b0;
    enable_16bit = 1'b0;
    challenge_16bit = 16'b0;
    $display("puf_1rbit configurations (4,1) and (16,1)");
    $display("CONFIG DUT_4BIT C_BITS=4 R_BITS=1 DELAY=%08h", DELAY_4BIT);
    $display("CONFIG DUT_16BIT C_BITS=16 R_BITS=1 DELAY=%032h", DELAY_16BIT);

    #1;
    reset_4bit = 1'b1;
    reset_16bit = 1'b1;
    #(SETTLE_16BIT);
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0, "initial reset");
    check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b0, "initial reset");
    reset_4bit = 1'b0;
    reset_16bit = 1'b0;
    #(SETTLE_16BIT);
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0, "idle with enable low");
    check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b0, "idle with enable low");

    for (sweep = 1; sweep <= 2; sweep = sweep + 1) begin
        $display("Four-bit challenge sweep %0d of 2", sweep);
        for (c = 0; c < 16; c = c + 1)
            measure_4bit(c[3:0]);
    end

    $display("Four-bit retention and asynchronous reset");
    measure_4bit(4'b0001); // Capture 1 before testing retention and clearing.
    enable_4bit = 1'b0;
    #(SETTLE_4BIT);
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b1,
                 "response retained after enable falls");
    enable_4bit = 1'b1;
    #(SETTLE_4BIT);
    reset_4bit = 1'b1;
    #1;
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0,
                 "asynchronous reset while clock stays high");
    reset_4bit = 1'b0;
    #(SETTLE_4BIT);
    check_result("DUT_4BIT", challenge_4bit, resp_4bit, 1'b0,
                 "no recapture without a new clock edge");
    enable_4bit = 1'b0;

    for (sweep = 1; sweep <= 2; sweep = sweep + 1) begin
        $display("Sixteen-bit directed sweep %0d of 2", sweep);
        for (c = 0; c < 44; c = c + 1)
            measure_16bit(c);
    end

    $display("Sixteen-bit retention and asynchronous reset");
    // The last directed challenge (DEAD) captures 1.
    enable_16bit = 1'b0;
    #(SETTLE_16BIT);
    check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b1,
                 "response retained after enable falls");
    enable_16bit = 1'b1;
    #(SETTLE_16BIT);
    reset_16bit = 1'b1;
    #1;
    check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b0,
                 "asynchronous reset while clock stays high");
    reset_16bit = 1'b0;
    #(SETTLE_16BIT);
    check_result("DUT_16BIT", challenge_16bit, resp_16bit, 1'b0,
                 "no recapture without a new clock edge");

    if (failures == 0)
        $display("PASS: all %0d checks passed; 0 failures.", checks);
    else
        $display("FAIL: %0d of %0d checks failed.", failures, checks);
    $stop;
end

endmodule
