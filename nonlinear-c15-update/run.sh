#!/bin/sh

EPC_IP=192.168.10.10
BBB_IP=192.168.10.11

# general Messages
MSG_DO_NOT_SWITCH_OFF="DO NOT SWITCH OFF C15!"
MSG_STARTING_UPDATE="Starting C15 update..."
MSG_UPDATING_C15="Updating C15"
MSG_UPDATING_EPC="1/3 Updating..."
MSG_UPDATING_BBB="2/3 Updating..."
MSG_UPDATING_RT_FIRMWARE="3/3 Updating..."
MSG_DONE="DONE!"
MSG_FAILED="FAILED!"
MSG_FAILED_WITH_ERROR_CODE="FAILED! Error Code:"
MSG_CHECK_LOG="Please check update log!"
MSG_RESTART="Please Restart!"

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

freeze() {
    while true; do
        sleep 1
    done
}

configure_ssh() {
    echo "Host 192.168.10.10
            StrictHostKeyChecking no
            UserKnownHostsFile=/dev/null
            " > ~/.ssh/config
    chmod 400 ~/.ssh/config
}

report() {
    pretty "$1" "$2" "$3" "$2" "$3"
    printf "$2" >> /update/errors.log
    echo "$2" | systemd-cat -t "C15_Update"
}

executeAsRoot() {
    echo "sscl" | /update/utilities/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$EPC_IP "sudo -S /bin/bash -c '$1' 1>&2 > /dev/null"
    return $?
}

executeOnWin() {
    /update/utilities/sshpass -p 'TEST' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no TEST@$EPC_IP "$1" 1>&2 > /dev/null
    return $?
}

wait4epc() {
    TIMEOUT=$1
    for COUNTER in $(seq 1 $TIMEOUT); do
        echo "waiting for OS response ... $COUNTER/$TIMEOUT"
        sleep 1
        executeAsRoot "exit" && return 0
    done
    return 1
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

epc_fix() {
    /update/utilities/sshpass -p "sscl" scp -r /update/EPC/epc_fix.sh sscl@192.168.10.10:/tmp
    executeAsRoot "cd /tmp && chmod +x epc_fix.sh && ./epc_fix.sh"
    return $?
}

epc_upgrade() {
    pretty "" "Upgrading C15..." "$MSG_DO_NOT_SWITCH_OFF" "Upgrading C15..." "$MSG_DO_NOT_SWITCH_OFF"

    if ! executeAsRoot "exit"; then
        if ! executeOnWin "mountvol p: /s & p: & DIR P:\nonlinear"; then      
            report "" "Upgrade not possible..." "Contact Nonlinear Labs!"
            return 1
        fi

        if [ ! -f /mnt/usb-stick/nonlinear-c15-major-upgrade.tar ]; then
            report "" "Missing upgrade.tar..." "Please download to USB!"
            return 1
        fi

        if [ $(findmnt -nbo AVAIL -T /mnt/usb-stick/) -lt 2400000000 ]; then
            report "" "Not enough space on USB..." "At least 2.5 GB more needed!"
            return 1
        fi

        if [ $(findmnt -no FSTYPE -T /mnt/usb-stick/) != 'vfat' ]; then
            report "" "USB format wrong..." "Please format to FAT!"
            return 1
        fi

        pretty "" "This might take a while..." "Get a snack!" "This might take a while..." "Get a snack!"
        mkdir /mnt/usb-stick/upgrade
        tar -C /mnt/usb-stick/upgrade -xvf /mnt/usb-stick/nonlinear-c15-major-upgrade.tar
        rm -rf /mnt/usb-stick/nonlinear-c15-major-upgrade.tar

        pretty "" "checking files..." "$MSG_DO_NOT_SWITCH_OFF" "checking files..." "$MSG_DO_NOT_SWITCH_OFF"
        checksum=$(sha256sum /mnt/usb-stick/upgrade/win2lin.tar| cut -d " " -f 1)
        checksumFile=/mnt/usb-stick/upgrade/${checksum}.sign

        if [ ! -f ${checksumFile} ]; then
            report "" "Upgrade file corrupt..." "Please download again!"
            return 1
        fi

        pretty "" "unpacking files..." "$MSG_DO_NOT_SWITCH_OFF" "unpacking files..." "$MSG_DO_NOT_SWITCH_OFF"
        tar -C /mnt/usb-stick/upgrade -xvf /mnt/usb-stick/upgrade/win2lin.tar
        rm -rf /mnt/usb-stick/upgrade/win2lin.tar
        cd /mnt/usb-stick/upgrade
        chmod +x ./upgrade50Plus.sh

        if ! /bin/sh ./upgrade50Plus.sh "/update/utilities" $EPC_IP; then
            report "" "Upgrade failed..." "Please contact Nonlinear Labs!"
            return 1;
        fi
    fi

    pretty "" "Upgrading C15..." "$MSG_DONE" "Upgrading C15..." "$MSG_DONE"
    sleep 2
    return 0
}


epc_update() {
    pretty "" "$MSG_UPDATING_EPC" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_EPC" "$MSG_DO_NOT_SWITCH_OFF"

    if ! epc_push_update; then
        epc_pull_update
        return_code=$?
        if [ $return_code -ne 0 ]; then
            pretty "" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
            sleep 2
            return 1
        fi
    fi

    epc_fix
    return_code=$?
    if [ $return_code -ne 0 ]; then
        /update/utilities/sshpass -p "sscl" scp -r sscl@192.168.10.10:/tmp/fix_error.log /dev/stdout | cat - >> /update/errors.log
        pretty "" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_EPC" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
        sleep 2
        return 1
    fi

    executeAsRoot "reboot"
    wait4epc 60

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
    pretty "" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_DO_NOT_SWITCH_OFF"
    chmod +x /update/LPC/lpc_update.sh
    chmod +x /update/LPC/lpc_check.sh
    rm -f /update/mxli.log

    /bin/sh /update/LPC/lpc_update.sh /update/LPC/main.bin A && sleep 1 && /bin/sh /update/LPC/lpc_check.sh 5

    # error codes 30...39
    return_code=$?
    if [ $return_code -ne 0 ]; then
        pretty "" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_FAILED_WITH_ERROR_CODE $return_code" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_FAILED_WITH_ERROR_CODE $return_code"
        sleep 2
        return 1;
    fi

    pretty "" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_DONE" "$MSG_UPDATING_RT_FIRMWARE" "$MSG_DONE"
    sleep 2
    return 0
}

stop_services() {
    systemctl stop playground > /dev/null || executeAsRoot "systemctl stop playground"
    systemctl stop bbbb > /dev/null
    return 0
}

main() {
    rm -f /mnt/usb-stick/nonlinear-c15-update.log.txt
    rm -f /update/errors.log
    touch /update/errors.log
    chmod +x /update/utilities/*

    ls -l /update/
    configure_ssh
    stop_services

    if ! epc_upgrade; then
        cp /update/errors.log /mnt/usb-stick/nonlinear-c15-update.log.txt
        cd /update && rm -r /mnt/usb-stick/upgrade
        freeze
    fi

    cd /update && rm -r /mnt/usb-stick/upgrade

    pretty "" "$MSG_STARTING_UPDATE" "$MSG_DO_NOT_SWITCH_OFF" "$MSG_STARTING_UPDATE" "$MSG_DO_NOT_SWITCH_OFF"
    sleep 2

    epc_update
    bbb_update
    lpc_update

    if [ $(wc -c /update/errors.log | awk '{print $1}') -ne 0 ]; then
        cp /update/errors.log /mnt/usb-stick/nonlinear-c15-update.log.txt
        pretty "" "$MSG_UPDATING_C15 $MSG_FAILED" "$MSG_CHECK_LOG" "$MSG_UPDATING_C15 $MSG_FAILED" "$MSG_CHECK_LOG"
        freeze
    fi

    pretty "" "$MSG_UPDATING_C15 $MSG_DONE" "$MSG_RESTART" "$MSG_UPDATING_C15 $MSG_DONE" "$MSG_RESTART"
    freeze
    return 0
}

main $1
