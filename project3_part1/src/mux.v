module mux #(
  parameter [3:0] DELAY = 10
)(
    input a,
    input b,
    input sel,

    output out
);

wire mux_a;
wire mux_b;

assign out = sel ? mux_a : mux_b;

process_delay_model #(
  .DELAY(DELAY[1:0]) //1st 2bits of DELAY  decided the integeral value of delay
) PDM_A(
  .wire_in(a),
  .wire_out(mux_a)
);

process_delay_model #(
  .DELAY(DELAY[3:2])
) PDM_B(
  .wire_in(b),
  .wire_out(mux_b)
);

endmodule
