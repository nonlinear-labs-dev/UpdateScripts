#!/bin/sh

# BASE_DIR=$(dirname "$0")
BASE_DIR="$PWD"

# Textout via text2soled is duplicated with different paths because multiple versions of the C15 Linux exist

function print2soled {
	Text=$1
        echo "$1"
	/nonlinear/text2soled/text2soled clear
        /nonlinear/text2soled/text2soled $Text 10 80
	/nonlinear/text2soled clear
	/nonlinear/text2soled $Text 10 80
}

print2soled "Starting Update"

systemctl stop playground
systemctl stop bbbb

rm -r /internalstorage/preset-manager/

if [ -d "$BASE_DIR/LPC/" ]; then
        print2soled "LPC Update"
        chmod +x $BASE_DIR/LPC/lpc_update.sh
        /bin/sh $BASE_DIR/LPC/lpc_update.sh $BASE_DIR/LPC/blob.bin
fi

if [ -d "$BASE_DIR/BBB/" ]; then
        print2soled "BBB Update"
        chmod +x $BASE_DIR/BBB/bbb_update.sh
        /bin/sh $BASE_DIR/BBB/bbb_update.sh
fi

if [ -d "$BASE_DIR/EPC/" ]; then
        print2soled "ePC Update"
        chmod +x $BASE_DIR/EPC/epc_update.sh
        /bin/sh $BASE_DIR/EPC/epc_update.sh
fi


systemctl restart bbbb
systemctl restart playground

print2soled "Done, please Restart!"
