`timescale 1ps/1ps
module tb_mux();
    // Preserve the original DUT setting: a has 0 ps delay; b has 2 ps delay.
    localparam [3:0] DELAY = 4'd8;
    reg a;
    reg b;
    reg sel;
    wire out;
    integer checks;
    integer failures;

    mux #(
        .DELAY(DELAY)
    ) DUT (
        .a(a),
        .b(b),
        .sel(sel),
        .out(out)
    );

    always #1 $display("TIME %g, A: %b, B: %b, SEL: %b, OUT: %b",
                       $time, a, b, sel, out);

    task check_out;
        input expected;
        input [8*64-1:0] description;
        begin
            checks = checks + 1;
            if (out !== expected) begin
                failures = failures + 1;
                $display("%0t FAIL A=%b B=%b SEL=%b expected=%b actual=%b : %0s",
                         $time, a, b, sel, expected, out, description);
            end
            else begin
                $display("%0t PASS A=%b B=%b SEL=%b expected=%b actual=%b : %0s",
                         $time, a, b, sel, expected, out, description);
            end
        end
    endtask

    initial begin
        $timeformat(-12, 0, " ps", 0);
        checks = 0;
        failures = 0;
        a = 1'b1;
        b = 1'b0;
        sel = 1'b1;
        $display("Mux test: SEL=1 selects A; SEL=0 selects delayed B");

        // Original SEL=1 input states and their transition at 20 ps.
        #1;
        check_out(1'b1, "SEL=1 selects A=1 while B=0");
        #19;
        b = 1'b1;
        a = 1'b0;
        #1;
        check_out(1'b0, "SEL=1 selects A=0 while B=1");

        // At 40 ps, B is already settled high; switching select chooses B.
        #19;
        sel = 1'b0;
        #1;
        check_out(1'b1, "SEL=0 selects the already-settled B=1 while A=0");

        // At 60 ps B falls. Check before and after its 2 ps delay.
        #19;
        a = 1'b1;
        b = 1'b0;
        #1;
        check_out(1'b1, "B falling: output retains one before the 2 ps delay");
        #2;
        check_out(1'b0, "SEL=0 follows B=0 after its 2 ps delay while A=1");

        // At 80 ps B rises. Sample away from the delayed transition at 82 ps.
        #17;
        a = 1'b0;
        b = 1'b1;
        #1;
        check_out(1'b0, "B rising: output retains zero before the 2 ps delay");
        #2;
        check_out(1'b1, "SEL=0 follows B=1 after its 2 ps delay while A=0");

        // Changing only the unselected input must leave the output unchanged.
        #7;
        a = 1'b1;
        #1;
        check_out(1'b1, "SEL=0 ignores a change on the unselected A input");
        #9;

        if (failures == 0)
            $display("PASS: all %0d checks passed; 0 failures.", checks);
        else
            $display("FAIL: %0d of %0d checks failed.", failures, checks);
        $stop;
    end
endmodule
