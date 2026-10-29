#####################################################
# Create Modelsim library and compile design files. #
#####################################################

#   @module : run_test
#   @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
#   Copyright (c) 2022 Trireme (STAM/SCAI/ASU)

# Create a library for working in
vlib work

set rtl ../

vlog -quiet $rtl/src/*.v
vlog -quiet $rtl/tb/*.v

quit
