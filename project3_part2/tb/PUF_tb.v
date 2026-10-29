`timescale 1ns/1ps

// iverilog -g2012 -s PUF_tb -o PUF_tb.vvp ../sources/RO_basic.v ../sources/Counter_group.v ../sources/PUF.v PUF_tb.v
// vvp PUF_tb.vvp                   (add +dump to write a VCD)
// Add +full for full-length counting; default seeds counters near completion
// after checking startup/counting, then exercises the real threshold logic.
module PUF_tb;
  reg reset = 1;
  reg [3:0] Cha0 = 0, Cha1 = 1;
  wire [3:0] Response;
  integer edge_count [0:63];
  integer offset0 [0:3];
  integer offset1 [0:3];
  integer index;
  reg [63:0] stopped_outputs;

  PUF dut (.reset(reset), .Cha0(Cha0), .Cha1(Cha1), .Response(Response));

  // As in RO_basic_tb, delay only the feedback connection. The production
  // source has zero-delay loops. Delays here are synthetic test stimulus,
  // not FPGA timing: alternating 2/3 ns half-periods give known winners,
  // with opposite winners in adjacent groups to test response bit mapping.
  genvar ro;
  generate
    for (ro = 0; ro < 64; ro = ro + 1) begin: oscillator_model
      localparam integer HALF_PERIOD = 2 + ((ro % 16 + ro / 16) % 2);
      wire feedback;
      assign #(HALF_PERIOD) feedback = dut.gen_Ro[ro].ro_inst.not_8;
      initial force dut.gen_Ro[ro].ro_inst.RO_in = feedback;

      always @(posedge dut.RO_out[ro] or posedge reset) begin
        if (reset) edge_count[ro] = 0;
        else edge_count[ro] = edge_count[ro] + 1;
      end
    end
  endgenerate

  task check_counts;
    begin
      // Compare the integrated counter wiring against edges observed at
      // each selected oscillator, including natural 16-bit rollover.
      if ((dut.cg0.count_num0 !== ((edge_count[Cha0] + offset0[0]) & 16'hffff)) ||
          (dut.cg0.count_num1 !== ((edge_count[Cha1] + offset1[0]) & 16'hffff)) ||
          (dut.cg1.count_num0 !== ((edge_count[16 + Cha0] + offset0[1]) & 16'hffff)) ||
          (dut.cg1.count_num1 !== ((edge_count[16 + Cha1] + offset1[1]) & 16'hffff)) ||
          (dut.cg2.count_num0 !== ((edge_count[32 + Cha0] + offset0[2]) & 16'hffff)) ||
          (dut.cg2.count_num1 !== ((edge_count[32 + Cha1] + offset1[2]) & 16'hffff)) ||
          (dut.cg3.count_num0 !== ((edge_count[48 + Cha0] + offset0[3]) & 16'hffff)) ||
          (dut.cg3.count_num1 !== ((edge_count[48 + Cha1] + offset1[3]) & 16'hffff)))
        $fatal(1, "At %0t: integrated counts disagree with selected oscillator edges", $time);
    end
  endtask

  task apply_reset;
    begin
      reset = 1;
      for (index = 0; index < 4; index = index + 1) begin
        offset0[index] = 0;
        offset1[index] = 0;
      end
      #11;
      if ((Response !== 4'b0000) || (dut.RO_out !== 64'b0) ||
          ({dut.cg3.resp1, dut.cg2.resp1, dut.cg1.resp1, dut.cg0.resp1} !== 4'b0000))
        $fatal(1, "Reset failed to clear responses or stop oscillators");
      check_counts;
      stopped_outputs = dut.RO_out;
      #13;
      if (dut.RO_out !== stopped_outputs)
        $fatal(1, "Oscillators did not remain stopped under reset");
      check_counts;
    end
  endtask

  task run_challenge;
    input [3:0] challenge0, challenge1, expected_response;
    begin
      apply_reset;
      Cha0 = challenge0;
      Cha1 = challenge1;
      #1;
      reset = 0;
      // Odd offset avoids sampling an oscillator edge or its NBA updates.
      #1001;
      for (index = 0; index < 64; index = index + 1)
        if (edge_count[index] < 100)
          $fatal(1, "Oscillator %0d failed to sustain oscillation", index);
      if (Response !== 4'b0000)
        $fatal(1, "Response asserted before the counter threshold");
      check_counts;
      $display("PASS: challenges %0d/%0d startup, all 64 oscillators, and initial counter wiring", Cha0, Cha1);
      $fflush();

      if ($test$plusargs("full")) begin
        // Slowest modeled oscillator reaches 65535 edges within 393210 ns.
        #392220;
      end else begin
        // Deposit rather than force: subsequent edges still update the DUT.
        // Offsets keep the scoreboard tied to observed oscillator edges.
        for (index = 0; index < 4; index = index + 1) begin
          offset0[index] = 65530 - edge_count[16 * index + Cha0];
          offset1[index] = 65530 - edge_count[16 * index + Cha1];
        end
        dut.cg0.count_num0 = 65530; dut.cg0.count_num1 = 65530;
        dut.cg1.count_num0 = 65530; dut.cg1.count_num1 = 65530;
        dut.cg2.count_num0 = 65530; dut.cg2.count_num1 = 65530;
        dut.cg3.count_num0 = 65530; dut.cg3.count_num1 = 65530;
        #41;
      end
      check_counts;
      if (Response !== expected_response)
        $fatal(1, "Challenges %0d/%0d: Response=%b, expected %b",
               Cha0, Cha1, Response, expected_response);
      if ({dut.cg3.resp1, dut.cg2.resp1, dut.cg1.resp1, dut.cg0.resp1} !== 4'b1111)
        $fatal(1, "Not all second counters reached their threshold");
      #101;
      check_counts;
      if (Response !== expected_response)
        $fatal(1, "Response did not remain stable after completion");
      $display("PASS: challenges %0d/%0d -> Response %b; all 64 ROs oscillate and counts match",
               Cha0, Cha1, Response);
    end
  endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("PUF_tb.vcd");
      $dumpvars(0, PUF_tb);
    end
    // Generate an explicit reset edge after feedback forces are installed.
    #1;
    reset = 0;
    #1;
    run_challenge(0, 1, 4'b0101);
    run_challenge(1, 0, 4'b1010);
    // Equal challenges use the same oscillator. Current RTL sets resp0
    // on the simultaneous threshold edge, as covered in Counter_group_tb.
    run_challenge(5, 5, 4'b1111);
    apply_reset;
    $display("PASS: PUF_tb, including reset after completed responses");
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "PUF_tb timed out");
  end
endmodule
