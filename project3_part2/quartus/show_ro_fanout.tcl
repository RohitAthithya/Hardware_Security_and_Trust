# Display the fitted fan-out connections of this project's 64 ring oscillators.
# Open Project3 and Tools > Chip Planner first. In the Quartus GUI Tcl Console:
#     source /home/cen598/Documents/cen598/Project3/project3_part2/quartus/show_ro_fanout.tcl
# Sourcing draws all 64 ROs. Subsequent commands:
#     show_ro_fanout 0          ;# RO 0 only (use Clear Connections first)
#     show_ro_fanout all        ;# All 64 ROs
#     show_ro_fanout 0 1        ;# RO 0, expand to routing-resource connections
#
# These are display operations, not routing or placement assignments. The fitted
# netlist, QSF, and SOF are not changed. A terminal quartus_sh cannot draw a GUI.
# Uses the Chip Planner GUI API shipped with Quartus Prime Lite 21.1.

proc ro_fanout_require_gui {} {
    if {[llength [info commands gui_find]] == 0} {
        # The GUI's internal acvq package is not advertised by load_package.
        # Register its installed initializer if it is not already available.
        if {![info exists ::quartus(binpath)] ||
                [llength [info commands execute_menu_item]] == 0} {
            error "Run this script in the Quartus GUI Tcl Console with Chip Planner open, not in quartus_sh or quartus_cdb."
        }
        set init_file [file normalize [file join $::quartus(binpath) .. common tcl internal init acvq.tcl]]
        if {![file isfile $init_file]} {
            error "Chip Planner GUI initializer not found: $init_file"
        }
        source $init_file
        package require ::quartus::acvq
    }
    foreach command {gui_find get_collection_size gen_connection render zoom_on} {
        if {[llength [info commands $command]] == 0} {
            error "Chip Planner command '$command' is unavailable. Open the fitted design in Chip Planner first."
        }
    }
}

proc show_ro_fanout {{which all} {routing 0}} {
    if {$which ne "all" &&
            (![string is integer -strict $which] || $which < 0 || $which > 63)} {
        error "Usage: show_ro_fanout all|RO_INDEX ?routing?; RO_INDEX must be 0 through 63."
    }
    if {$routing ni {0 1}} {
        error "The routing argument must be 0 (connection arrows) or 1 (expanded routing connections)."
    }
    ro_fanout_require_gui

    if {$which eq "all"} {
        set pattern {*RO_basic:gen_Ro*.ro_inst|*}
        set expected 640
        set label "all 64 ROs"
    } else {
        # '?' matches each literal bus bracket without Tcl/glob escaping issues.
        set pattern [format {*RO_basic:gen_Ro?%d?.ro_inst|*} $which]
        set expected 10
        set label "RO $which"
    }
    set nodes [gui_find -atoms $pattern]
    set node_count [get_collection_size $nodes]
    if {$node_count != $expected} {
        error "Found $node_count RO cells for $label; expected $expected. Load the fitted Project3 design in Chip Planner and check its hierarchy."
    }

    # 'ultimate' connects the source logic cell to each destination logic cell;
    # it does not recursively traverse the feedback loop.
    set connections [gen_connection $nodes -fanout -ultimate]
    set connection_count [get_collection_size $connections]
    if {$connection_count == 0} {
        error "No fitted fan-out connections found for $label."
    }
    if {$routing} {
        if {[llength [info commands expand_connections]] == 0} {
            error "This Chip Planner session does not expose expand_connections. Use show_ro_fanout $which 0."
        }
        render [expand_connections $connections]
    } else {
        render $connections
    }
    zoom_on $nodes
    puts "Displayed $connection_count fan-out connections from $node_count cells ($label)."
    return $connection_count
}

show_ro_fanout all
