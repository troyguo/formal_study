clear -all
analyze -sv combination_lock.vs
elaborate -bbox_mul 1024
clock clk
reset -expression rst -max_iterations 100

prove -all