# simple RD6006 interactions via modbus RTU

## USAGE:

    rd6006_op.pl [options]

    options:
    [-h] -- help;
    [-d] -- debug;
    [-m /dev/device] -- device file, default =  /dev/ttyUSB0;
    [-u unit] -- modbus device unit, default=1;
    [-O=off] -- off power after mesurement;
    [-v v_set] -- initial voltage set;
    [ -i i_set ] -- initial current set;
    [-V d_v] -- voltage delta on every iteration;
    [-I d_i] -- currtnt delta on every iteration;
    [-n n_read] -- number of iterations;
    [-t t_read] -- additional delay between iterations.



