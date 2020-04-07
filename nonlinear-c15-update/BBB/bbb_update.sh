#!/bin/sh

#
# Author: Anton Schmied
# version : 2.0
#
# ----------- install a BBB Updates from USB-Stick ---------
#
# This script will transfer the /preset-manager/* and settings.xml to the ePC
# and update the BBB excluding the /update directory
#

EPC_IP=$1
BBB_IP=$2

report_and_quit(){
    printf "$1" >> /update/errors.log
    exit $2
}

executeAsRoot() {
    echo "sscl" | /update/utilities/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$EPC_IP \
        "sudo -S /bin/bash -c '$1' 1>&2 > /dev/null"
    return $?
}

check_preconditions(){
    if [ -e /settings.xml ] &&
        [ ! -z "$EPC_IP" ] &&
        ping -c1 $EPC_IP 1>&2 > /dev/null &&
        executeAsRoot "exit" &&
        executeAsRoot "mountpoint -q /persistent"; then
        return 0
     fi
     return 1
}

move_files(){
    if ! check_preconditions; then
        return 1
    fi

    executeAsRoot "systemctl stop playground"

    if [ -d /internalstorage/preset-manager ] && [ "$(ls -A /internalstorage/preset-manager/)" ]; then
        executeAsRoot "scp -r root@$BBB_IP:/internalstorage/preset-manager/ /persistent" \
        && rm -rf /internalstorage/preset-manager/* \
        && rm -rf /internalstorage/preset-manager
        if [ $? -ne 0 ]; then report_and_quit "E55 BBB update: Moving presets to ePC failed ..." "55"; fi
    fi

    if [ -e /settings.xml ]; then
        executeAsRoot "scp root@$BBB_IP:/settings.xml /persistent/settings.xml" \
        && rm /settings.xml
        if [ $? -ne 0 ]; then report_and_quit "E56 BBB update: Moving Settings to ePC failed ..." "56"; fi
    fi

    if [ -d /internalstorage/calibration ] && [ "$(ls -A /internalstorage/calibration/)" ]; then
        executeAsRoot "scp -r root@$BBB_IP:/internalstorage/calibration/ /persistent" \
        && rm -rf /internalstorage/calibration/* \
        && rm -rf /internalstorage/calibration
        if [ $? -ne 0 ]; then report_and_quit "E57 BBB update: Moving calibration settings to ePC failed ..." "57"; fi
    fi

    return 0
}

update(){
    mkdir /update/BBB/rootfs \
    && gzip -dc /update/BBB/rootfs.tar.gz | tar -C /update/BBB/rootfs -xf - \
    && LD_LIBRARY_PATH=/update/utilities /update/utilities/rsync -cax --exclude 'etc/hostapd.conf' -f 'P update/' --delete /update/BBB/rootfs/ / \
    && chown -R root.root /update
    if [ $? -ne 0 ]; then report_and_quit "E58 BBB update: Syncing rootfs failed ..." "58"; fi
    rm -rf /update/BBB/rootfs/*
    rm -rf /update/BBB/rootfs
}

main() {
    move_files
    update

    return 0
}

main



