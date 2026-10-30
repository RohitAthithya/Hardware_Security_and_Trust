`timescale 1ns/1ps
module tb_puf_top;
    reg [3:0] KEY = 4'hf;
    reg [9:0] SW = 0;
    wire [7:0] LEDG;
    wire [9:0] LEDR;

    cyclone_v_top dut (
        .CLOCK_50_B5B(1'b0), .CLOCK_50_B6A(1'b0),
        .CLOCK_50_B7A(1'b0), .CLOCK_50_B8A(1'b0),
        .CPU_RESET_n(1'b1), .KEY(KEY), .SW(SW), .LEDG(LEDG), .LEDR(LEDR)
    );

    // Module-scope defparams avoid modifying instances across generate scopes.
    // Only challenge indices 0, 1, and 4 are used by this integration bench.
    defparam dut.puf_inst.gen_Ro[0].ro_inst.HALF_PERIOD = 1.0;
    defparam dut.puf_inst.gen_Ro[1].ro_inst.HALF_PERIOD = 2.0;
    defparam dut.puf_inst.gen_Ro[4].ro_inst.HALF_PERIOD = 2.0;
    defparam dut.puf_inst.gen_Ro[16].ro_inst.HALF_PERIOD = 4.0;
    defparam dut.puf_inst.gen_Ro[17].ro_inst.HALF_PERIOD = 2.0;
    defparam dut.puf_inst.gen_Ro[20].ro_inst.HALF_PERIOD = 2.0;
    defparam dut.puf_inst.gen_Ro[32].ro_inst.HALF_PERIOD = 3.0;
    defparam dut.puf_inst.gen_Ro[33].ro_inst.HALF_PERIOD = 6.0;
    defparam dut.puf_inst.gen_Ro[36].ro_inst.HALF_PERIOD = 6.0;
    defparam dut.puf_inst.gen_Ro[48].ro_inst.HALF_PERIOD = 8.0;
    defparam dut.puf_inst.gen_Ro[49].ro_inst.HALF_PERIOD = 4.0;
    defparam dut.puf_inst.gen_Ro[52].ro_inst.HALF_PERIOD = 4.0;

    `include "test_support.svh"

    task restart(input [3:0] c0, input [3:0] c1);
        begin
            KEY[0] = 0;
            SW[3:0] = c0;
            SW[7:4] = c1;
            #20;
            check(LEDG == 0 && LEDR == 0, "active-low KEY0 clears all LEDs/status");
            check(dut.puf_inst.RO_out == 0, "reset disables all simulated ROs");
            check(dut.puf_inst.Cha0 == c0 && dut.puf_inst.Cha1 == c1,
                "switch nibbles map to the correct challenge inputs");
            KEY[0] = 1;
        end
    endtask

    initial begin
        restart(0, 1);
        wait (dut.puf_inst.group_done[0]);
        #0.1;
        check(!LEDG[4] && !(&dut.puf_inst.group_done), "Done waits for all four groups");
        wait (LEDG[4]);
        #1;
        check(LEDG[3:0] == 4'b1010 && LEDR[3:0] == 0,
            "four independent RO slices produce mixed expected winners");
        check(LEDG[7:5] == 0 && LEDR[9:4] == 0, "unused LEDs are low");
        #100;
        check(LEDG == 8'h1a && LEDR == 0, "finished response persists");
        restart(1, 0);
        wait (LEDG[4]);
        #1;
        check(LEDG[3:0] == 4'b0101 && LEDR == 0, "swapping challenges reverses winners");
        restart(4, 4);
        wait (LEDG[4]);
        #1;
        check(LEDR[3:0] == 4'b1111, "all four invalid flags map to red LEDs");
        restart(0, 1);
        #50;
        check(!LEDG[4] && LEDR == 0, "new measurement starts after all clocks were stopped");
        restart(1, 0);
        wait (LEDG[4]);
        #1;
        check(LEDG[3:0] == 4'b0101 && LEDR == 0, "reset during counting restarts cleanly");
        $display("PASS: tb_puf_top %0d checks", checks);
        $finish;
    end

    initial begin
        #4000000;
        $fatal(1, "PUF integration test timeout");
    end
endmodule
