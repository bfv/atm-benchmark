*
* ATM performance test:
* Structure file for a small database on a single disk.
* You must change this file if you want a larger database or more disks
* See the readme file for directions
*
* 21-Sep-1995 ghb
*

#
b .
#
d "Schema Area":6,64;1 .
#
d "Data Area":10,256;8 .
#
d "Index Area":20,32;8 .

a atm.a1    f 2048
a atm.a2    f 2048
a atm.a3    f 2048
a atm.a4    f 2048

