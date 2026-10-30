module tb_process_delay_model();

parameter DELAY = 10;
reg wire_in;
wire wire_out;

process_delay_model #(
  .DELAY(DELAY)
) DUT (
  .wire_in(wire_in),
  .wire_out(wire_out)
);

always #1 $display("TIME %g, IN: %b, OUT: %b", $time, wire_in, wire_out);

initial begin
  wire_in = 1'b0;
  #3
  wire_in = 1'b1;
  #3
  wire_in = 1'b0;
  #20
  wire_in = 1'b1;
  #20
  wire_in = 1'b0;
  #20
  $stop;
end






endmodule
