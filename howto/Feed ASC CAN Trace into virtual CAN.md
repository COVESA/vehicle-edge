When working with controll unit teams CAN traces sometimes come in a ASC format like this:
``` 
date Mon Feb 1 08:40:23.073 am 2021
base hex  timestamps absolute
internal events logged
// version 9.0.0
Begin Triggerblock Mon Feb 1 08:40:23.073 am 2021
   0.000000 Start of measurement
   0.002191 1  6AC             Rx   d 8 01 01 01 00 FA 00 00 00  Length = 238019 BitCount = 123 ID = 1708
   0.002439 1  6AD             Rx   d 8 00 00 00 00 00 00 00 00  Length = 239762 BitCount = 124 ID = 1709
   0.002741 1  1FFFF000x       Rx   d 8 00 00 00 00 00 00 00 00  Length = 294019 BitCount = 151 ID = 536866816x
``` 

to feed the virtual CAN bus the can-utils need to be in the "compact CAN Frame logfile" format:
``` 
(1616568513.030740) can0 6AC#01010100FA000000
(1616568513.030988) can0 6AD#0000000000000000
(1616568513.031290) can0 1FFFF000#0000000000000000
(1616568513.031590) can0 1FFFF001#0000000000000000
``` 

To convert them use the [asc2log](https://manpages.debian.org/unstable/can-utils/asc2log.1.en.html) tool, e.g.:
``` 
asc2log -I braking_in_N_1.asc -O myCAN.log
``` 

This generates myCAN.log in the desired format. This traces can now be "replayed" into the virtual CAN Bus. Note the above trace was coming from can0 and is now put into vcan0 :
``` 
canplayer vcan0=can0 -v -I myCAN.log
``` 

Any listener can now read vcan0 and act on it .. run a "candump vcan0" to watch the data coming in, see [here](https://sgframework.readthedocs.io/en/latest/cantutorial.html) for more details.