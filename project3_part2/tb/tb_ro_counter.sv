`timescale 1ns/1ps
module tb_ro_counter;
    reg clk = 0;
    reg reset = 0;
    wire [15:0] count;
    wire [3:0] short_count;
    wire one_count;
    wire done, short_done, one_done;
    integer i;

    ro_counter dut(clk, reset, count, done);
    ro_counter #(.W(4)) small_dut(clk, reset, short_count, short_done);
    ro_counter #(.W(1)) one_dut(clk, reset, one_count, one_done);

    `include "test_support.svh"

    task pulse;
        begin
            #1 clk = 1;
            #1 clk = 0;
            #1;
        end
    endtask

    initial begin
        #1 reset = 1;
        #1;
        check({count, short_count, one_count, done, short_done, one_done} == 0,
            "asynchronous reset without a clock edge");
        reset = 0;
        for (i = 1; i <= 65535; i = i + 1) begin
            pulse;
            check(count == i && done == (i == 65535), "16-bit exact count/completion");
            check(short_count == ((i < 15) ? i : 15) && short_done == (i >= 15),
                "parameterized 4-bit saturation");
            check(one_count == 1 && one_done, "W=1 saturation");
        end
        repeat (20) pulse;
        check(count == 16'hffff && done && short_count == 15 && short_done,
            "saturation and sticky done without rollover");
        #0.5 reset = 1;
        #0.1;
        check(count == 0 && !done, "reset after saturation");
        reset = 0;
        repeat (7) pulse;
        check(count == 7 && !done, "restart after saturation");
        #0.5 reset = 1;
        #0.1;
        check(count == 0 && !done && short_count == 0 && !short_done,
            "asynchronous reset mid-count");
        reset = 0;
        pulse;
        check(count == 1 && !done, "restart after interrupted measurement");
        $display("PASS: tb_ro_counter %0d checks", checks);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Counter test timeout");
    end
endmodule
