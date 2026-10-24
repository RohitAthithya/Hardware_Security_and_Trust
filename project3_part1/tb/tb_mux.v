module tb_mux();


parameter DELAY = 10;
reg a;
reg b;
reg sel;

wire out;

mux #(
  .DELAY(4'd10)
) DUT (
  .a(a),
  .b(b),
  .sel(sel),

  .out(out)
);

always #1 $display("TIME %g, A: %b, B: %b, SEL: %b, OUT: %b", $time, a, b, sel, out);

initial begin
  a =  1'b1;
  b =  1'b0;
  sel = 1'b1;

  #20
  b = 1'b1;
  a = 1'b0;

  #20
  $stop;
end


endmodule
