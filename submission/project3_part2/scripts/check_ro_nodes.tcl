# Run from quartus/: quartus_cdb -t ../scripts/check_ro_nodes.tcl
load_package chip_planner
project_open Project3
read_netlist
set count 0
set output [open output_files/ro_fitted_nodes.csv w]
puts $output "ro,gate,location,fanout,lut_mask"
for {set ro 0} {$ro < 64} {incr ro} {
    foreach gate {nand_out not_1 not_2 not_3 not_4 not_5 not_6 not_7 not_8 not_9} {
        set name [format {PUF:puf_inst|RO_basic:gen_Ro[%d].ro_inst|%s} $ro $gate]
        set node [get_node_by_name -name $name]
        if {$node == -1} {
            error "Missing synthesized RO stage: $name"
        }
        set location [get_node_info -node $node -info {Location String}]
        set fanout 0
        foreach_in_collection port [get_oports -node $node -as_gen_id] {
            if {[get_port_info -gen_id $port -info {Port Type}] == "COMBOUT"} {
                incr fanout [get_port_info -gen_id $port -info {Number of Fanout}]
            }
        }
        set mask [get_node_info -node $node -info {LUT Mask}]
        puts $output "$ro,$gate,$location,$fanout,$mask"
        incr count
    }
}
close $output
puts "PASS: $count required RO stage nodes exist (64 distinct ten-stage ROs)"
project_close
