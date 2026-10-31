#!/usr/bin/env bash

#   @module : synth
#   @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
#   Copyright (c) 2022 (STAM/SCAI/ASU)


PROJECT=netlist_B

yosys -p "read -sv ./${PROJECT}.v
synth_ice40 -blif ./output/${PROJECT}.blif"


arachne-pnr -q  -d 1k -o ./output/${PROJECT}_bitstream.txt ./output/${PROJECT}.blif

icetime -d lp1k ./output/${PROJECT}_bitstream.txt
