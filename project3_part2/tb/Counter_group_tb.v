`timescale 1ns/1ps

// iverilog -g2012 -s Counter_group_tb -o Counter_group_tb.vvp ../sources/Counter_group.v Counter_group_tb.v
// vvp Counter_group_tb.vvp          (add +dump to write a VCD)
module Counter_group_tb;
  reg reset = 0;
  reg [3:0] Cha0 = 0, Cha1 = 1;
  reg [15:0] RO_out = 0;
  wire Response;
  integer selection, bit_number;
  integer expected0, expected1;

  Counter_group dut (.reset(reset), .Cha0(Cha0), .Cha1(Cha1),
                     .RO_out(RO_out), .Response(Response));

  task check_state;
    input [15:0] count0, count1;
    input response0, response1;
    begin
      if ((dut.count_num0 !== count0) || (dut.count_num1 !== count1) ||
          (Response !== response0) || (dut.resp1 !== response1))
        $fatal(1, "At %0t: counts=%0d/%0d response=%b/%b; expected %0d/%0d %b/%b",
               $time, dut.count_num0, dut.count_num1, Response, dut.resp1,
               count0, count1, response0, response1);
    end
  endtask

  task apply_reset;
    begin
      reset = 1;
      #2;
      check_state(0, 0, 0, 0);
      RO_out = 0;
      #2;
      reset = 0;
      #2;
    end
  endtask

  // Every pulse starts and finishes low. Checks occur after NBA updates.
  task pulse;
    input [15:0] mask;
    input integer number;
    begin
      repeat (number) begin
        RO_out = mask;
        #2;
        RO_out = 0;
        #2;
      end
    end
  endtask

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("Counter_group_tb.vcd");
      $dumpvars(0, Counter_group_tb);
    end
    #1;
    // Exercise every input against every challenge value. The two selectors
    // use opposite orders, so swapped or incorrectly indexed muxes fail.
    for (selection = 0; selection < 16; selection = selection + 1) begin
      apply_reset;
      Cha0 = selection;
      Cha1 = 15 - selection;
      expected0 = 0;
      expected1 = 0;
      #1;
      for (bit_number = 0; bit_number < 16; bit_number = bit_number + 1) begin
        pulse(16'h0001 << bit_number, 1);
        if (bit_number == selection) expected0 = expected0 + 1;
        if (bit_number == 15 - selection) expected1 = expected1 + 1;
        check_state(expected0, expected1, 0, 0);
      end
    end
    $display("PASS: all 16 selections on both muxes; unselected inputs ignored");

    apply_reset;
    Cha0 = 0;
    Cha1 = 1;
    #1;
    pulse(16'h0001, 65534);
    check_state(65534, 0, 0, 0);
    pulse(16'h0001, 1);
    check_state(65535, 0, 1, 0);
    pulse(16'h0002, 65535);
    check_state(65535, 65535, 1, 1);
    pulse(16'h0003, 1);
    check_state(0, 0, 1, 1);
    pulse(16'h0003, 5);
    check_state(5, 5, 1, 1);
    $display("PASS: first counter wins on edge 65535; response stays set through rollover");

    apply_reset;
    pulse(16'h0002, 65534);
    check_state(0, 65534, 0, 0);
    pulse(16'h0002, 1);
    check_state(0, 65535, 0, 1);
    pulse(16'h0001, 65535);
    check_state(65535, 65535, 0, 1);
    $display("PASS: second counter wins and blocks the first response");

    apply_reset;
    Cha0 = 7;
    Cha1 = 7;
    #1;
    pulse(16'h0080, 65534);
    check_state(65534, 65534, 0, 0);
    pulse(16'h0080, 1);
    // Current RTL accepts the first response on a simultaneous finish:
    // both always blocks read the old resp1 before nonblocking updates.
    check_state(65535, 65535, 1, 1);
    $display("PASS: identical challenges count together; simultaneous finish sets Response");

    // Assert reset without waiting for an oscillator edge, then keep inputs
    // toggling under reset to verify that counting remains inhibited.
    reset = 1;
    #1;
    check_state(0, 0, 0, 0);
    pulse(16'hffff, 10);
    check_state(0, 0, 0, 0);
    reset = 0;
    #1;
    pulse(16'h0080, 1);
    check_state(1, 1, 0, 0);
    $display("PASS: asynchronous reset, reset hold, and restart");
    $display("PASS: Counter_group_tb");
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "Counter_group_tb timed out");
  end
endmodule
