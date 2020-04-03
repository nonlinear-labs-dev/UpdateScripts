#!/bin/sh
#
#
# Name:         Anton Schmied
# Date:         2020.02.27
# Version:      2.0
# TODO:         Trouble Shooting if one of the updates does not work?
#               Save to journalctl
#               Where to save the update log, if update is not from USB-Stick?
#               -> under /persistent/ ?? or is bbb journalctl enough?

# ePC IP
EPC_IP=192.168.10.10
BBB_IP=192.168.10.11

# general Messages
MSG_DO_NOT_SWITCH_OFF="DO NOT SWITCH OFF C15!"
MSG_UPDATING_C15="updating C15..."
MSG_UPDATING_RT_FIRMWARE_1="updating RT-System 1..."
MSG_UPDATING_RT_FIRMWARE_2="updating RT-System 2..."
MSG_UPDATING_EPC="updating ePC..."
MSG_UPDATING_BBB="updating BBB..."
MSG_DONE="DONE"
MSG_FAILED="FAILED"
MSG_FAILED_WITH_ERROR_CODE="FAILED! Error Code: "

t2s() {
    /update/utilities/text2soled multitext "$1" "$2" "$3" "$4" "$5" "$6"
}

pretty() {
    echo "$*"
    HEADLINE="$1"
    BOLED_LINE_1="$2"
    BOLED_LINE_2="$3"
    SOLED_LINE_2="$4"
    SOLED_LINE_3="$5"

    t2s "${HEADLINE}@b1c" "${BOLED_LINE_1}@b3c" "${BOLED_LINE_2}@b4c" "${SOLED_LINE_2}@s1c" "${SOLED_LINE_3}@s2c"
}

report_and_quit() {
    pretty "$1" "$2" "$3" "$4" "$5" "$6"
    echo "$2 $3" | systemd-cat -t "C15_Update"
#    exit 1
}

epc_push_update() {
    chmod +x /update/EPC/epc_push_update.sh
    /bin/sh /update/EPC/epc_push_update.sh $EPC_IP
    return $?
}

epc_pull_update() {
    chmod +x /update/EPC/epc_pull_update.sh
    /bin/sh /update/EPC/epc_pull_update.sh $EPC_IP
    return $?
}

# TODO:
#     check if win2lin is needed
#     check if win2lin is possible
#     check if major-upgrade.tar is present and not corrupt (checksum)
#     upgrade

executeAsRoot() {
    echo "sscl" | /update/utilities/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$EPC_IP "sudo -S /bin/bash -c '$1' 1>&2 > /dev/null"
    return $?
}

executeOnWin() {
    /update/utilities/sshpass -p 'TEST' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no TEST@$EPC_IP "$1" 1>&2 > /dev/null
    return $?
}

epc_upgrade() {
    pretty "" "upgrading C15..." "$MSG_DO_NOT_SWITCH_OFF" "upgrading C15..." "$MSG_DO_NOT_SWITCH_OFF"

    if ! executeAsRoot "exit"; then
        if ! executeOnWin "mountvol p: /s & p: & DIR P:\nonlinear"; then
            printf "Ubuntu partition on the ePC not found" >> /update/errors.log
            return 1
        fi

        if [ ! -f /mnt/usb-stick/nonlinear-c15-major-upgrade.tar ]; then
            printf "missing major-upgrade file" >> /update/errors.log
            return 1
        fi

        if [ $(findmnt -nbo AVAIL -T /mnt/usb-stick/) -lt 2400000000 ]; then
            printf "not enough space on the usb stick" >> /update/errors.log
            return 1
        fi

        if [ $(findmnt -no FSTYPE -T /mnt/usb-stick/) != 'vfat' ]; then
            printf "usb stick is not of the right format" >> /update/errors.log
            return 1
        fi

        pretty "" "this might take a while..." "get a snack!" "" "this might take a while..." "get a snack!"
        mkdir /mnt/usb-stick/upgrade
        tar -C /mnt/usb-stick/upgrade -xvf /mnt/usb-stick/nonlinear-c15-major-upgrade.tar
        rm -rf /mnt/usb-stick/nonlinear-c15-major-upgrade.tar

        pretty "" "checking files..." "$MSG_DO_NOT_SWITCH_OFF" "checking files..." "$MSG_DO_NOT_SWITCH_OFF"
        checksum=$(sha256sum /mnt/usb-stick/upgrade/win2lin.tar| cut -d " " -f 1)
        checksumFile=/mnt/usb-stick/upgrade/${checksum}.sign

        if [ ! -f ${checksumFile} ]; then
            printf "major-upgrade file corrupt" >> /update/errors.log
            return 1
        fi

        pretty "" "unpacking files..." "$MSG_DO_NOT_SWITCH_OFF" "unpacking files..." "$MSG_DO_NOT_SWITCH_OFF"
        tar -C /mnt/usb-stick/upgrade -xvf /mnt/usb-stick/upgrade/win2lin.tar
        rm -rf /mnt/usb-stick/upgrade/win2lin.tar
        cd /mnt/usb-stick/upgrade
        chmod +x ./upgrade50Plus.sh

        if ! /bin/sh ./upgrade50Plus.sh "/update/utilities" $EPC_IP; then
            printf "major-upgrade failed..." >> /update/errors.log
            return 1;
        fi
    fi

    pretty "" "upgrading C15..." "$MSG_DONE" "upgrading C15..." "$MSG_DONE"
    sleep 2
    return 0
}


epc_update() {
    pretty "" "$MSG_UPDATING_EPC" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_EPC" "$MSG_DO_NOT_SWITCH_OFF"

    if ! epc_push_update; then
        if ! epc_pull_update; then
            pretty "" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
            sleep 2
            return 1
        fi
    fi

    pretty "" "$MSG_UPDATING_EPC" "$MSG_DONE" "$MSG_UPDATING_EPC" "$MSG_DONE"
    sleep 2
    return 0
}


bbb_update() {
    pretty "" "$MSG_UPDATING_BBB" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_BBB" "$MSG_DO_NOT_SWITCH_OFF"
    chmod +x /update/BBB/bbb_update.sh
    /bin/sh /update/BBB/bbb_update.sh $EPC_IP $BBB_IP

    # error codes 50...59
    return_code=$?
    if [ $return_code -ne 0 ]; then
        pretty "" "$MSG_UPDATING_BBB" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_BBB" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
        sleep 2
        return 1;
    fi

    pretty "" "$MSG_UPDATING_BBB" "$MSG_DONE" "$MSG_UPDATING_BBB" "$MSG_DONE"
    sleep 2
    return 0
}

lpc_update() {
    pretty "" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_DO_NOT_SWITCH_OFF"
    chmod +x /update/LPC/lpc_update.sh
    rm -f /update/mxli.log

    /bin/sh /update/LPC/lpc_update.sh /update/LPC/M0_project.bin B

    # error codes 30...39
    return_code=$?
    if [ $return_code -ne 0 ]; then
        pretty "" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
        sleep 2
        return 1;
    fi

    pretty "" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_DONE" "$MSG_UPDATING_RT_FIRMWARE_1" "$MSG_DONE"
    sleep 2

    pretty "" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_DO_NOT_SWITCH_OFF"
    /bin/sh /update/LPC/lpc_update.sh /update/LPC/M4_project.bin A

    # error codes 30...39
    return_code=$?
    if [ $return_code -ne 0 ]; then
        pretty "" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
        sleep 2
        return 1;
    fi

    pretty "" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_DONE" "$MSG_UPDATING_RT_FIRMWARE_2" "$MSG_DONE"
    sleep 2
    return 0
}

configure_ssh() {
    echo "Host 192.168.10.10
            StrictHostKeyChecking no
            UserKnownHostsFile=/dev/null
            " > ~/.ssh/config
    chmod 400 ~/.ssh/config
}

stop_services() {
    systemctl stop playground > /dev/null
    systemctl stop bbbb > /dev/null
}

rebootEPC() {
    echo "sscl" | /update/utilities/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$EPC_IP "sudo reboot"
}

rebootBBB() {
    reboot
}

main() {
    rm -f /update/errors.log
    touch /update/errors.log

    configure_ssh
    stop_services

    if ! epc_upgrade; then
        cp /update/errors.log /mnt/usb-stick/nonlinear-c15-update.log.txt
        rm -r /mnt/usb-stick/upgrade
        pretty "" "cannot upgrade your C15" "please contact NL!" "cannot upgrade your C15" "please contact NL!"
        while true; do
            sleep 1
        done
    fi
    rm -r /mnt/usb-stick/upgrade

    epc_update
    bbb_update
    lpc_update


    if [ $(wc -c /update/errors.log | awk '{print $1}') -ne 0 ]; then
        cp /update/errors.log /mnt/usb-stick/nonlinear-c15-update.log.txt
        pretty "" "updating C15 FAILED!" "please contact NL!" "updating C15 FAILED!" "please contact NL!"
        while true; do
            sleep 1
        done
    fi

    pretty "" "$MSG_UPDATING_C15" "$MSG_DONE" "$MSG_UPDATING_C15" "$MSG_DONE"
    sleep 4
    pretty "" "Rebooting System..." "" "Rebooting System..." ""
    sleep 2

    rebootEPC
    rebootBBB
}

main
