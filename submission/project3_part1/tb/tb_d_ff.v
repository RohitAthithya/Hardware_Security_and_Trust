`timescale 1ps/1ps

module tb_d_ff();
    reg d;
    reg clk;
    reg reset;
    wire q;
    integer checks;
    integer failures;

    d_ff DUT (.q(q), .d(d), .clk(clk), .reset(reset));

    task check_q;
        input expected;
        input [8*80-1:0] description;
        begin
            checks = checks + 1;
            if (q !== expected) begin
                failures = failures + 1;
                $display("%0t FAIL d=%b clk=%b reset=%b expected=%b actual=%b : %0s",
                         $time, d, clk, reset, expected, q, description);
            end
            else begin
                $display("%0t PASS d=%b clk=%b reset=%b expected=%b actual=%b : %0s",
                         $time, d, clk, reset, expected, q, description);
            end
        end
    endtask

    task capture;
        input value;
        begin
            clk = 1'b0;
            #2;
            d = value;
            #2;
            clk = 1'b1;
            // Sample after the DUT's nonblocking assignment has settled.
            #1;
            check_q(value, "rising-edge capture, including repeated data values");
        end
    endtask

    initial begin
        $timeformat(-12, 0, " ps", 0);
        checks = 0;
        failures = 0;
        d = 1'b0;
        clk = 1'b0;
        reset = 1'b0;
        $display("Standalone d_ff: capture, retention, asynchronous reset and reset priority");

        #1;
        reset = 1'b1;
        #1;
        check_q(1'b0, "initial asynchronous reset with clock stopped low");
        reset = 1'b0;
        #1;
        check_q(1'b0, "reset release does not capture data");

        d = 1'b1;
        #2;
        check_q(1'b0, "data change with clock low retains the previous result");
        clk = 1'b1;
        #1;
        check_q(1'b1, "rising clock captures one");
        d = 1'b0;
        #2;
        check_q(1'b1, "data change with clock high retains the previous result");
        clk = 1'b0;
        #1;
        check_q(1'b1, "falling clock does not capture zero");
        clk = 1'b1;
        #1;
        check_q(1'b0, "next rising clock captures zero");

        capture(1'b0);
        capture(1'b1);
        capture(1'b1);
        capture(1'b0);
        capture(1'b1);

        clk = 1'b0;
        #2;
        reset = 1'b1;
        #1;
        check_q(1'b0, "asynchronous reset clears a stored one with clock stopped low");
        d = 1'b0;
        #1;
        check_q(1'b0, "asserted reset holds zero while data falls");
        d = 1'b1;
        #1;
        check_q(1'b0, "asserted reset holds zero while data rises");
        clk = 1'b1;
        #1;
        check_q(1'b0, "reset dominates rising clock with data one");
        clk = 1'b0;
        #1;
        clk = 1'b1;
        #1;
        check_q(1'b0, "reset remains dominant over another clock cycle");
        reset = 1'b0;
        #1;
        check_q(1'b0, "reset release with clock high does not recapture one");
        clk = 1'b0;
        #1;
        check_q(1'b0, "falling clock after reset release retains zero");
        clk = 1'b1;
        #1;
        check_q(1'b1, "fresh rising clock after reset captures one");

        reset = 1'b1;
        #1;
        check_q(1'b0, "asynchronous reset clears a stored one with clock stopped high");
        reset = 1'b0;
        #2;
        check_q(1'b0, "clock held high after reset release cannot recapture");
        d = 1'b0;
        #1;
        check_q(1'b0, "data falls after reset release without a clock edge");
        d = 1'b1;
        #1;
        check_q(1'b0, "data rises after reset release without a clock edge");
        capture(1'b1);

        clk = 1'b0;
        #2;
        reset = 1'b1;
        clk = 1'b1;
        #1;
        check_q(1'b0, "simultaneous reset assertion and rising clock give reset priority");
        reset = 1'b0;
        #1;
        check_q(1'b0, "final reset release retains zero without another rising clock");

        if (failures == 0)
            $display("PASS: all %0d checks passed; 0 failures.", checks);
        else
            $display("FAIL: %0d of %0d checks failed.", failures, checks);
        $stop;
    end
endmodule
