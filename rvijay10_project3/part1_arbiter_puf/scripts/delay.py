#! /usr/bin/env python3
import random
import sys

def gen_delay(num_delays):
    delay = "{"
    for i in range(num_delays-1):
        #delay += "4'd"+str(random.randint(0,15))+", "
        delay += "4'd"+str(int(random.uniform(0,15)))+", "

    delay += "4'd"+str(int(random.uniform(0,15)))+"}"
    return delay

if __name__ == "__main__":

    if(len(sys.argv)!= 4):
        print("Usage: "+sys.argv[0]+" C_BITS R_BITS OUTPUT_FILE")
        print("4-bit Challenge, 8-bit Response Example:")
        print(sys.argv[0]+" 4 8 delay_params.v")
        exit()

    c_bits = int(sys.argv[1])
    r_bits = int(sys.argv[2])

    delay = gen_delay(c_bits*r_bits*2)

    param = "parameter [2*4*C_BITS*R_BITS-1:0] DELAY = "+ delay + ";"

    with open(sys.argv[3],'w') as f:
        f.write(param)

