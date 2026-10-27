module d_ff(output reg q, input d,clk,reset);

always@(posedge clk or posedge reset)
begin
    if(reset)
    q <= 1'b0;

    else
    q <= d;

end

endmodule