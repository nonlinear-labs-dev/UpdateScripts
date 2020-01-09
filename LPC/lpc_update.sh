 #!/bin/sh
LPC_FIRMWARE=$1

if [ -z "$1" ]; then
	echo "no argument supplied, expected path to lpc firmware blob!"
	exit 1
fi

if [ ! -f $LPC_FIRMWARE ]; then
	echo "no file in $LPC_FIRMWARE"
	exit 1
f
i
function export_gpio {
	GPIO=$1
	echo $GPIO > /sys/class/gpio/export
	sleep 0.1
	echo out > /sys/class/gpio/gpio$GPIO/direction
	sleep 0.1
}

function unexport_gpio {
	GPIO=$1
	echo $GPIO > /sys/class/gpio/unexport
	sleep 0.1
}

function write_to_gpio {
	GPIO=$1
	VALUE=$2
	echo $VALUE > /sys/class/gpio/gpio$GPIO/value
	sleep 0.1
}

function write_blob {
	/nonlinear/scripts/mxli -v -d /dev/ttyUSB0 -N LPC4337 -E -b115200 -T500 -c12000000 -F8kix8,64kix7 -B1024,4096 -A0x1A000000,0x1B000000 -M32ki@0x10000000 -I0xA001CA30,0xXXXXXX00 -R0x200@0x1008000,-288@0x10000000 -S8@7 -yA $LPC_FIRMWARE
}

ISP=48
RESET=50
PROGMODE=115
export_gpio $ISP
export_gpio $RESET
export_gpio $PROGMODE
write_to_gpio $ISP 1
write_to_gpio $RESET 1
write_to_gpio $PROGMODE 1
write_to_gpio $ISP 0
write_to_gpio $RESET 0
write_to_gpio $RESET 1
write_to_gpio $ISP 1
write_blob
write_to_gpio $PROGMODE 0
write_to_gpio $RESET 0
write_to_gpio $RESET 1
unexport_gpio $PROGMODE
unexport_gpio $RESET
unexport_gpio $ISP
