`timescale 1ns/1ps

// Run from this directory with Icarus Verilog:
//   iverilog -g2012 -s RO_basic_tb -o /tmp/RO_basic_tb.vvp ../sources/RO_basic.v RO_basic_tb.v
//   vvp /tmp/RO_basic_tb.vvp
// Waveforms are written to RO_basic_tb.vcd.
//
// The source has no propagation delays. Insert one delay at the feedback
// connection to let simulation time advance. This exercises the DUT's logic;
// it does not predict the physical oscillator frequency or stage delays.
module RO_basic_tb;
  parameter integer LOOP_DELAY_NS = 9;
  localparam integer PERIOD_NS = 2 * LOOP_DELAY_NS;

  reg Enable;
  wire RO_out;
  wire delayed_feedback;
  integer transitions = 0;
  integer rising_edges = 0;
  integer falling_edges = 0;
  integer errors = 0;
  reg monitor_timing = 0;
  reg have_previous_edge = 0;
  realtime previous_edge;
  realtime edge_spacing;

  RO_basic dut (.Enable(Enable), .RO_out(RO_out));

  // Nine inversions lie in the loop: the NAND and not_1 through not_8.
  // not_9 drives the output but is outside the feedback loop.
  assign #(LOOP_DELAY_NS) delayed_feedback = dut.not_8;

  always @(RO_out) begin
    transitions = transitions + 1;
    if (RO_out === 1'b1)
      rising_edges = rising_edges + 1;
    else if (RO_out === 1'b0)
      falling_edges = falling_edges + 1;

    if (monitor_timing) begin
      if ((RO_out !== 1'b0) && (RO_out !== 1'b1)) begin
        $display("FAIL at %0t: RO_out is X/Z while enabled", $time);
        errors = errors + 1;
      end else begin
        if (have_previous_edge) begin
          edge_spacing = $realtime - previous_edge;
          if ((edge_spacing < LOOP_DELAY_NS - 0.001) ||
              (edge_spacing > LOOP_DELAY_NS + 0.001)) begin
            $display("FAIL at %0t: edge spacing %0.3f ns, expected %0d ns",
                     $time, edge_spacing, LOOP_DELAY_NS);
            errors = errors + 1;
          end
        end
        previous_edge = $realtime;
        have_previous_edge = 1;
      end
    end
  end

  task check_disabled;
    integer before_transitions;
    begin
      monitor_timing = 0;
      Enable = 0;
      // Allow feedback and all zero-delay assignments to settle.
      #(3 * LOOP_DELAY_NS + 1);
      if (RO_out !== 1'b0) begin
        $display("FAIL at %0t: disabled output must be 0", $time);
        errors = errors + 1;
      end
      before_transitions = transitions;
      #(4 * PERIOD_NS + 1);
      if (transitions != before_transitions) begin
        $display("FAIL at %0t: output toggled while disabled", $time);
        errors = errors + 1;
      end
    end
  endtask

  task check_enabled;
    input integer run_number;
    integer before_rising;
    integer before_falling;
    begin
      before_rising = rising_edges;
      before_falling = falling_edges;
      have_previous_edge = 0;
      monitor_timing = 1;
      Enable = 1;
      // The extra 1 ns keeps checks away from expected edge times.
      #(12 * PERIOD_NS + 1);
      monitor_timing = 0;
      if ((rising_edges - before_rising < 10) ||
          (falling_edges - before_falling < 10)) begin
        $display("FAIL run %0d: insufficient oscillation (%0d rising, %0d falling)",
                 run_number, rising_edges - before_rising,
                 falling_edges - before_falling);
        errors = errors + 1;
      end
      $display("Run %0d: %0d rising, %0d falling edges; modeled period = %0d ns",
               run_number, rising_edges - before_rising,
               falling_edges - before_falling, PERIOD_NS);
    end
  endtask

  initial begin
    if (LOOP_DELAY_NS <= 0)
      $fatal(1, "LOOP_DELAY_NS must be positive");

    $dumpfile("RO_basic_tb.vcd");
    $dumpvars(0, RO_basic_tb);
    Enable = 0;
    // Override only the feedback connection, using the DUT's own not_8.
    // Do not release it while enabled: the original loop has zero delay.
    force dut.RO_in = delayed_feedback;

    check_disabled;
    check_enabled(1);
    check_disabled;
    check_enabled(2);
    check_disabled;
    check_enabled(3);
    check_disabled;

    if (errors != 0)
      $fatal(1, "RO_basic_tb FAILED: %0d error(s)", errors);
    $display("PASS: startup, sustained oscillation, edge spacing, shutdown, and restart");
    $finish;
  end

  initial begin
    #(200 * PERIOD_NS + 100);
    $fatal(1, "RO_basic_tb timed out");
  end
endmodule
