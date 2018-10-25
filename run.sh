#!/bin/sh

BASE_DIR=$(dirname "$0")

# Textout via text2soled is duplicated with different paths because multiple versions of the C15 Linux exist

systemctl stop playground

function print2soled {
	Text=$1
	/nonlinear/text2soled/text2soled clear
	/nonlinear/text2soled clear
	/nonlinear/text2soled $Text 10 80
	/nonlinear/text2soled/text2soled $Text 10 80
}

print2soled "Starting Update"

if [ -d "/update/system/" ]; then
	print2soled "Operating System Update"
	chmod +x /update/system/system_update.sh
	/bin/sh /update/system/system_update.sh
fi

if [ -d "/update/LPC/" ]; then
	print2soled "Firmware Update"
	chmod +x /update/LPC/lpc_update.sh
	/bin/sh /update/LPC/lpc_update.sh /update/LPC/blob.bin
fi

if [ -d "/update/EPC/" ]; then
	print2soled "Audio Engine Update"
	chmod +x /update/EPC/epc_update.sh
	/bin/sh /update/EPC/epc_update.sh
fi

if [ -d "/update/BBB/" ]; then
	print2soled "UI Software Update"
	chmod +x /update/BBB/bbb_update.sh
	/bin/sh /update/BBB/bbb_update.sh
fi

if [ -d "/update/uboot/" ]; then
	print2soled "U-Boot Update"
	chmod +x /update/uboot/update-uboot.sh
	/bin/sh /update/uboot/update-uboot.sh 1>${BASE_DIR}/uboot.stdout.log 2>${BASE_DIR}/uboot.stderr.log
        cp ${BASE_DIR}/*.log /mnt/usb-stick
fi

systemctl stop playground
print2soled "Done, please Restart!"
