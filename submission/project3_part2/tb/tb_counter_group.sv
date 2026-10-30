`timescale 1ns/1ps
module tb_counter_group;
    reg reset = 0;
    reg [3:0] Cha0 = 0;
    reg [3:0] Cha1 = 1;
    reg [15:0] RO_out = 0;
    wire Response, Done, Invalid;
    integer i, index, unused_index, winner;
    reg [15:0] frozen_count;

    Counter_group dut(Response, Done, Invalid, reset, Cha0, Cha1, RO_out);
    `include "test_support.svh"

    task restart(input [3:0] c0, input [3:0] c1);
        begin
            reset = 1;
            RO_out = 0;
            Cha0 = c0;
            Cha1 = c1;
            #2;
            check(dut.count0 == 0 && dut.count1 == 0 && !Done && !Invalid && !Response,
                "reset clears counters and status even after clocks stopped");
            reset = 0;
            #1;
        end
    endtask

    task pulse_mask(input [15:0] mask);
        begin
            RO_out = mask;
            #1;
            RO_out = 0;
            #1;
        end
    endtask

    initial begin
        for (index = 0; index < 16; index = index + 1) begin
            restart(index, 15-index);
            pulse_mask(16'b1 << index);
            check(dut.count0 == 1 && dut.count1 == 0, "mux0 selects correct RO index");
            repeat (2) pulse_mask(16'b1 << (15-index));
            check(dut.count0 == 1 && dut.count1 == 2, "mux1 selects correct RO index");
            unused_index = (index + 1) % 16;
            while (unused_index == 15-index)
                unused_index = (unused_index + 1) % 16;
            pulse_mask(16'b1 << unused_index);
            check(dut.count0 == 1 && dut.count1 == 2, "unselected RO does not count");
        end
        restart(2, 13);
        repeat (3) pulse_mask(16'h2004);
        check(dut.count0 == 3 && dut.count1 == 3 && !Done && !Invalid,
            "equal intermediate values are not invalid");

        for (winner = 0; winner < 2; winner = winner + 1) begin
            restart(2, 13);
            for (i = 1; i <= 65535; i = i + 1) begin
                if (winner == 0)
                    pulse_mask((i % 2 == 0) ? 16'h2004 : 16'h0004);
                else
                    pulse_mask((i % 2 == 0) ? 16'h2004 : 16'h2000);
            end
            check(Done && !Invalid && Response == winner, "correct first-finisher response");
            if (winner == 0) begin
                check(dut.count0 == 65535 && dut.count1 == 32767 && dut.clk1 == 0,
                    "counter0 saturation and stopped counter1");
                frozen_count = dut.count1;
            end
            else begin
                check(dut.count1 == 65535 && dut.count0 == 32767 && dut.clk0 == 0,
                    "counter1 saturation and stopped counter0");
                frozen_count = dut.count0;
            end
            repeat (32) pulse_mask(16'hffff);
            check((winner == 0 ? dut.count1 : dut.count0) == frozen_count,
                "loser stays frozen despite more input edges");
            check(Done && !Invalid && Response == winner, "response stays stable");
            $display("PASS: counter%0d won, count0=%0d count1=%0d", winner,
                dut.count0, dut.count1);
        end

        restart(6, 6);
        repeat (65535) pulse_mask(16'h0040);
        check(Done && Invalid && dut.count0 == 65535 && dut.count1 == 65535,
            "same selected RO gives invalid tie in ideal RTL");
        repeat (8) pulse_mask(16'hffff);
        check(Invalid && dut.clk0 == 0 && dut.clk1 == 0, "tie holds both clocks stopped");

        restart(0, 15);
        repeat (65535) pulse_mask(16'h8001);
        check(Done && Invalid, "different ROs with simultaneous terminal edges are invalid");
        restart(7, 8);
        pulse_mask(16'h0080);
        check(dut.count0 == 1 && dut.count1 == 0 && !Done && !Invalid,
            "reset recovers after invalid measurement");
        restart(7, 8);
        $display("PASS: tb_counter_group %0d checks", checks);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "Counter group test timeout");
    end
endmodule
