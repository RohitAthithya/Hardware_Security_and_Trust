    integer checks = 0;

    task check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %s at %0t", message, $time);
                $fatal(1, "Self-check failed");
            end
        end
    endtask
