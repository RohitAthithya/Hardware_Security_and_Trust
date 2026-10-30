`timescale 1ns/1ps
module tb_ro_basic;
    reg Enable = 0;
    wire RO_out;
    integer edges = 0;
    integer before_edges;
    time last_edge;
    time measured_period;
    RO_basic_delayed dut(Enable, RO_out);
    `include "test_support.svh"

    always @(posedge RO_out) begin
        if (Enable) begin
            edges = edges + 1;
            measured_period = $time - last_edge;
            last_edge = $time;
        end
    end

    initial begin
        #40;
        check(RO_out === 1'b0, "disabled delayed gate model settles low");
        Enable = 1;
        #200;
        check(edges >= 10, "enabled delayed gate model oscillates");
        check(measured_period == 18, "nine 1ns feedback stages give an 18ns model period");
        Enable = 0;
        #40;
        check(RO_out === 1'b0, "disable stops oscillation after settling");
        before_edges = edges;
        #50;
        check(RO_out === 1'b0 && edges == before_edges, "disabled output stays low");
        Enable = 1;
        #200;
        check(edges > before_edges + 8, "oscillation restarts after enable");
        $display("PASS: tb_ro_basic %0d checks; delay-model period only, not FPGA frequency", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "RO model test timeout");
    end
endmodule
