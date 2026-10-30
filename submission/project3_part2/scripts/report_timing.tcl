# Run from quartus/: quartus_sta -t ../scripts/report_timing.tcl
project_open Project3
create_timing_netlist
read_sdc
update_timing_netlist
if {[get_collection_size [get_clocks *]] != 8} {
    error "Expected eight analysis clocks"
}
report_timing -setup -npaths 20 -detail full_path -file output_files/setup_paths.txt
report_timing -hold -npaths 20 -detail full_path -file output_files/hold_paths.txt
report_min_pulse_width -nworst 20 -file output_files/min_pulse_width.txt
report_clock_fmax_summary -file output_files/clock_fmax.txt
report_clock_transfers -file output_files/clock_transfers.txt
check_timing -file output_files/check_timing.txt
set stream [open output_files/timing_slack.csv w]
puts $stream "check,worst_slack_ns"
foreach mode {setup hold} {
    set paths [get_timing_paths -$mode -npaths 1]
    foreach_in_collection path $paths {
        puts $stream "$mode,[get_path_info -slack $path]"
    }
}
close $stream
puts "PASS: timing reports generated for eight RO-derived analysis clocks"
delete_timing_netlist
project_close
