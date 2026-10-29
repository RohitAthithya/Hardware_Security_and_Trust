# No external/system clock is used by this design.
# 5ns is an initial analysis target, NOT a measurement of RO frequency.
set RO_MIN_PERIOD_NS 5.0
for {set group 0} {$group < 4} {incr group} {
    for {set counter 0} {$counter < 2} {incr counter} {
        set name [format {puf_inst|cg%d|clk%d|combout} $group $counter]
        set pin [get_pins $name]
        if {[get_collection_size $pin] != 1} {
            error "Expected one gated-clock output pin: $name"
        }
        create_clock -name ro_cg${group}_${counter} -period $RO_MIN_PERIOD_NS $pin
    }
}
# Keep all counter-to-counter control paths visible to timing analysis.
# No blanket false paths or asynchronous clock-group cuts are applied.
derive_clock_uncertainty
