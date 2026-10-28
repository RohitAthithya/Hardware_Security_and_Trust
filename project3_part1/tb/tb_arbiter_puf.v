`timescale 1ps/1ps

module tb_arbiter_puf();

localparam C_BITS = 4;
localparam R_BITS = 4;
localparam SETTLE = 16*7; // Covers the longest (seven-stage) DUT.

// Each 32-bit block configures one response bit, starting with bit 0 at the LSB.
// These four distinct delay profiles have no tied final arrivals for any of
// the 16 challenges. Each response bit produces both 0 and 1 across the sweep.
localparam [127:0] DELAY = {
  32'h7DF77F7A, 32'h7DDD77EB, 32'hDA997FDD, 32'hDF66FFAD
};

// Independently calculated truth tables: table bit c is the response to c.
localparam [15:0] EXPECT_R0 = 16'h69AA;
localparam [15:0] EXPECT_R1 = 16'h5995;
localparam [15:0] EXPECT_R2 = 16'h9669;
localparam [15:0] EXPECT_R3 = 16'h9969;

reg reset;
reg enable;
reg [C_BITS-1:0] challenge;
reg [6:0] challenge_wide;
wire [R_BITS-1:0] resp;
wire resp_min;
wire [31:0] resp_32;
wire [2:0] resp_wide;

integer checks;
integer failures;
integer sweep;
integer c;

arbiter_puf #(.C_BITS(C_BITS), .R_BITS(R_BITS), .DELAY(DELAY)) DUT_A (
  .reset(reset), .enable(enable), .challenge(challenge), .resp(resp)
);

// Minimum legal dimensions; challenge 0 -> response 0, challenge 1 -> response 1.
arbiter_puf #(.C_BITS(1), .R_BITS(1), .DELAY(8'h69)) DUT_MIN (
  .reset(reset), .enable(enable), .challenge(challenge[0]), .resp(resp_min)
);

// Repeat the four known profiles to exercise all 32 response connections.
// The expected 32-bit response is eight copies of the four-bit response.
arbiter_puf #(.C_BITS(4), .R_BITS(32), .DELAY({8{DELAY}})) DUT_32 (
  .reset(reset), .enable(enable), .challenge(challenge), .resp(resp_32)
);

// Different challenge width and non-power-of-two response width.
// Known answers below cover only the five selected seven-bit challenges.
arbiter_puf #(.C_BITS(7), .R_BITS(3), .DELAY({
  56'hED7BFA66EDBDF6, 56'h6BFEDE675DFE6F, 56'hEEB76B75FDBBAF
})) DUT_WIDE (
  .reset(reset), .enable(enable), .challenge(challenge_wide), .resp(resp_wide)
);

function [R_BITS-1:0] expected_response;
  input [C_BITS-1:0] challenge_in;
  begin
    expected_response = {EXPECT_R3[challenge_in], EXPECT_R2[challenge_in],
                         EXPECT_R1[challenge_in], EXPECT_R0[challenge_in]};
  end
endfunction

// Narrow responses are zero-extended for a common checker. Case inequality
// treats any unexpected X or Z bit as a failure instead of silently accepting it.
task check_result;
  input [8*16-1:0] dut_name;
  input [31:0] actual;
  input [31:0] expected;
  input [8*48-1:0] test_name;
  begin
    checks = checks + 1;
    if (actual !== expected) begin
      failures = failures + 1;
      $display("%0t FAIL %0s challenge=%07b expected=%08h actual=%08h : %0s",
               $time, dut_name, challenge_wide, expected, actual, test_name);
    end
    else
      $display("%0t PASS %0s challenge=%07b expected=%08h actual=%08h : %0s",
               $time, dut_name, challenge_wide, expected, actual, test_name);
  end
endtask

task check_all_zero;
  input [8*48-1:0] test_name;
  begin
    check_result("DUT_A (4,4)", resp, 4'b0, test_name);
    check_result("DUT_MIN (1,1)", resp_min, 1'b0, test_name);
    check_result("DUT_32 (4,32)", resp_32, 32'b0, test_name);
    check_result("DUT_WIDE (7,3)", resp_wide, 3'b0, test_name);
  end
endtask

task gen_crp;
  input [6:0] challenge_in;
  input check_wide;
  input [2:0] expected_wide;
  reg [R_BITS-1:0] expected;
  begin
    reset = 1'b1;
    enable = 1'b0;
    challenge = challenge_in[C_BITS-1:0];
    challenge_wide = challenge_in;
    #(SETTLE);
    check_result("DUT_A (4,4)", resp, 4'b0, "reset before measurement");
    check_result("DUT_32 (4,32)", resp_32, 32'b0, "reset before measurement");
    if (check_wide)
      check_result("DUT_WIDE (7,3)", resp_wide, 3'b0, "reset before measurement");

    reset = 1'b0;
    #1;
    enable = 1'b1;
    #(SETTLE);
    expected = expected_response(challenge);
    check_result("DUT_A (4,4)", resp, expected, "captured response");
    check_result("DUT_32 (4,32)", resp_32, {8{expected}}, "captured response");
    check_result("DUT_MIN (1,1)", resp_min, challenge[0], "captured response");
    if (check_wide)
      check_result("DUT_WIDE (7,3)", resp_wide, expected_wide, "captured response");
  end
endtask

initial begin
  $timeformat(-12, 0, " ps", 0);
  checks = 0;
  failures = 0;
  reset = 1'b0;
  enable = 1'b0;
  challenge = 4'b0;
  challenge_wide = 7'b0;
  $display("Arbiter PUF: known-answer, parameter, reset and repeatability checks");
  $display("Responses are hexadecimal; the 7-bit challenge is truncated to each DUT's width.");

  #1;
  reset = 1'b1;
  #(SETTLE);
  check_all_zero("initial reset");
  reset = 1'b0;
  #(SETTLE);
  check_all_zero("idle with enable low");

  // Both sweeps use fixed reference answers, so repeatability cannot pass
  // merely because the DUT produces the same incorrect response twice.
  for (sweep = 1; sweep <= 2; sweep = sweep + 1) begin
    $display("Four-bit challenge sweep %0d of 2", sweep);
    for (c = 0; c < 16; c = c + 1)
      gen_crp(c[6:0], 1'b0, 3'b0);
  end

  $display("Seven-bit challenge smoke tests");
  gen_crp(7'b0000000, 1'b1, 3'b100);
  gen_crp(7'b0000001, 1'b1, 3'b011);
  gen_crp(7'b1000000, 1'b1, 3'b100);
  gen_crp(7'b1010101, 1'b1, 3'b000);
  gen_crp(7'b1111111, 1'b1, 3'b101);

  // The last challenge gives nonzero responses on every DUT. They must be
  // retained after falling enable, then cleared asynchronously while enabled.
  enable = 1'b0;
  #(SETTLE);
  check_result("DUT_A (4,4)", resp, 4'hC, "response retained after enable falls");
  check_result("DUT_32 (4,32)", resp_32, 32'hCCCCCCCC, "response retained after enable falls");
  check_result("DUT_MIN (1,1)", resp_min, 1'b1, "response retained after enable falls");
  check_result("DUT_WIDE (7,3)", resp_wide, 3'b101, "response retained after enable falls");

  enable = 1'b1;
  #(SETTLE);
  reset = 1'b1;
  #1;
  check_all_zero("asynchronous reset while clock stays high");
  reset = 1'b0;
  #(SETTLE);
  check_all_zero("no recapture without a new clock edge");

  if (failures == 0)
    $display("PASS: all %0d checks passed; 0 failures.", checks);
  else
    $display("FAIL: %0d of %0d checks failed.", failures, checks);
  $stop;
end

endmodule
