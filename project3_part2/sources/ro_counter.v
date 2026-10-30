module ro_counter #(
    parameter integer W = 16
) (
    input wire ro_clk,
    input wire reset,
    output reg [W-1:0] count,
    output reg done
);

    localparam [W-1:0] MAX_COUNT = {W{1'b1}};
    localparam [W-1:0] BEFORE_MAX = MAX_COUNT - 1'b1;

    always @(posedge ro_clk or posedge reset) begin
        if (reset) begin
            count <= {W{1'b0}};
            done <= 1'b0;
        end
        else if (!done) begin
            if (count == BEFORE_MAX) begin
                count <= MAX_COUNT;
                done <= 1'b1;
            end
            else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule
