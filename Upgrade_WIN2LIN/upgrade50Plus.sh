#!/bin/bash
#
# Authours:     HH, AS
# Note:         The Error Messages are stored on the BBB. Use journalctl | grep ePC-Upgrade to show these
#
# IMPORTANT:    The OS-Overlay is stored in the 3rd Partition (./p3.raw.gz)
#               and should be of the last release for the actual update
# TODO:         Merge Partitions seems only to work for 64/120 GB SSD_SIZE, 32GB SSD fail

IP=192.168.10.10
SSD_SIZE=0
PART_POS=0
PART_SIZE=0
TIMEOUT=60
SSHPASS_PATH="/nonlinear/utilities"
CURRENT_PATH="$PWD"

wait4response() {
    COUNTER=0
    while true; do
        rm /root/.ssh/known_hosts 1>&2 > /dev/null;
        executeAsRoot "exit"
        [ $? -eq 0 ] && break

        sleep 1
        ((COUNTER++))
        echo "awaiting reboot ... $COUNTER/$TIMEOUT"
        [ $COUNTER -eq $TIMEOUT ] && { quit "Reboot taking too long..." "timed out" "" "Reboot fail..." "timed out"; break; }
    done
}

t2s() {
    /nonlinear/text2soled/text2soled multitext "- Do not switch off! -@s2c" "$1" "$2" "$3" "$4" "$5" "$6"
}

pretty() {
    echo "pretty arguments: $*"
    HEADLINE="$1"
    BOLED_LINE_1="$2"
    BOLED_LINE_2="$3"
    SOLED_LINE_1="$4"
    SOLED_LINE_2="$5"

    t2s "${HEADLINE}@b1c" "${BOLED_LINE_1}@b3c" "${BOLED_LINE_2}@b4c" "${SOLED_LINE_1}@s0c" "${SOLED_LINE_2}@s1c"
}

executeAsRoot() {
    echo "sscl" | $SSHPASS_PATH/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$IP "sudo -S /bin/bash -c '$1' 1>&2 > /dev/null"
    return $?
}

executeOnWin() {
    $SSHPASS_PATH/sshpass -p 'TEST' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no TEST@$IP "$1" 1>&2 > /dev/null
    return $?
}

quit() {
    pretty "$1" "$2" "$3" "$4" "$5" "$6"
    echo "$1 $2 $3" | systemd-cat -t "ePC-Upgrade"          # save error ouputs to journal
    exit 1
}

print_scp_progress() {
    TARGET_SIZE="0"
    SOURCE_SIZE=$(ls -lah $2 | awk {'print $5'})

    TARGET_SIZE_BYTES="0"
    SOURCE_SIZE_BYTES=$(ls -la $2 | awk {'print $5'})
    
    executeAsRoot "touch $2"

    while [ ! "$TARGET_SIZE_BYTES" = "$SOURCE_SIZE_BYTES" ]; do
        TARGET_SIZE=$($SSHPASS_PATH/sshpass -p 'sscl' ssh sscl@$IP "ls -lah $3 | awk {'print \$5'}")
        TARGET_SIZE_BYTES=$($SSHPASS_PATH/sshpass -p 'sscl' ssh sscl@$IP "ls -la $3 | awk {'print \$5'}")
        pretty "Copying..." "partition $1 content" "$TARGET_SIZE of $SOURCE_SIZE" "Copying partition $1" "$TARGET_SIZE / $SOURCE_SIZE"
        sleep 1
    done
}

print_dd_progress() {
    MSG=$1
    FILE=$2    
    touch $FILE
    while [ -e "$FILE" ]; do
        OUT=$(cat $FILE | tr '\r' '\n' | tail -n1 | grep -o "[0-9]* bytes")
        pretty "Dumping..." "partition $1 content" "$OUT Bytes." "Dumping partition $1" "$OUT Bytes."
        sleep 1 
    done    
}

check_connection() {
    pretty "Checking connection..." "ePC - BBB" "" "Checking connection..." "ePC - BBB"
    [ -z "$IP" ] && quit "Usage:" "$0 <IP-of-ePC>" "" "wrong usage" ""
    ping -c1 $IP 1>&2 > /dev/null || quit "No connection!" "ePC is not reachable at" "$IP, update failed." "Update failed." "ePC not reachable."

    if [ ! -x $SSHPASS_PATH/sshpass ]; then
        if [ ! -d "$SSHPASS_PATH"  ]; then
            mkdir $SSHPASS_PATH
        fi
        cp $CURRENT_PATH/utilities/sshpass $SSHPASS_PATH
        chmod +x $SSHPASS_PATH/sshpass
        rm /root/.ssh/known_hosts
    fi
    rm /root/.ssh/known_hosts 1>&2 > /dev/null
    executeOnWin "exit" || quit "Can't login into Windows" "Update failed." "" "Update failed." "No Windows login"
    pretty "Checking connection..." "done." "" "Checking connection..." "done."
}

get_hdw_info() {
    # complete diskdrive info via 'wmic diskdrive where (DeviceID='\\\\.\\PHYSICALDRIVE0') list /format:list'
    # EXAMPLE: 32 GB SSD
    #
    # BytesPerSector=512                    Capabilities={3,4,10}               CapabilityDescriptions={"Random Access","Supports Writing","SMART Notification"}
    # ConfigManagerErrorCode=0              ConfigManagerUserConfig=FALSE       Description=Disk drive
    # DeviceID=\\.\PHYSICALDRIVE0           Index=0                             InterfaceType=IDE
    # Manufacturer=(Standard disk drives)   MediaLoaded=TRUE                    MediaType=Fixed hard disk media
    # Model=TS32GMTS800S                    Name=\\.\PHYSICALDRIVE0             Partitions=4
    # PNPDeviceID=SCSI\DISK&amp;VEN_&amp;PROD_TS32GMTS800S\4&amp;20157ED9&amp;0&amp;020000
    # SCSIBus=2                             SCSILogicalUnit=0                   SCSIPort=0
    # SCSITargetId=0                        SectorsPerTrack=63                  Size=32012789760
    # Status=OK                             SystemName=DESKTOP-O4RBF7E          TotalCylinders=3892
    # TotalHeads=255                        TotalSectors=62524980               TotalTracks=992460
    # TracksPerCylinder=255

    pretty "Getting hardware info..." "" "" "Getting hardware info..." ""
    SSD_SIZE=$($SSHPASS_PATH/sshpass -p 'TEST' ssh -o StrictHostKeyChecking=no TEST@$IP "wmic diskdrive where (DeviceID='\\\\\\\\.\\\\PHYSICALDRIVE0') get size")
    SSD_SIZE=$(echo "$SSD_SIZE" | sed -n 2p)        # Size Info is in the second line
    SSD_SIZE=${SSD_SIZE//[ $'\001'-$'\037']}        # remove possible DOS carriage return characters
    SSD_SIZE=$((SSD_SIZE / 1000000000))
    if ! [[ $SSD_SIZE =~ ^[0-9]+$ ]]; then
        quit "SSD size is NaN" "" "" "SSD size" "is NaN"
    fi
    pretty "Getting hardware info..." "done." "" "Getting hardware info..." "done."
}

check_preconditions_win() {
    pretty "Checking preconditions..." "" "" "Checking" "preconditions..."
    if [ $SSD_SIZE -eq 32 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeOnWin "wmic partition get StartingOffset | findstr "21529362432"" || \
            quit "Unexpected partition" "ePC partition 3 is not at" "expected position, update failed." "Update failed." "partition error"
        executeOnWin "wmic partition get NumberOfBlocks | findstr "20482422"" || \
            quit "Unexpected partition" "ePC partition 3 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=$(( 21529362432 / 512))  # 42049536 Sectors
        PART_SIZE=20482422
    elif [ $SSD_SIZE -eq 64 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeOnWin "wmic partition get StartingOffset | findstr "32016171008"" || \
            quit "Unexpected partition" "ePC partition 3 is not at" "expected position, update failed." "Update failed." "partition error"
        executeOnWin "wmic partition get NumberOfBlocks | findstr "62513152"" || \
            quit "Unexpected partition" "ePC partition 3 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=$(( 32016171008 / 512 ))   # 62531584 Sectors
        PART_SIZE=62513152
    elif [ $SSD_SIZE -eq 120 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeOnWin "wmic partition get StartingOffset | findstr "32016171008"" || \
           quit "Unexpected partition" "ePC partition 3 is not at" "expected position, update failed." "Update failed." "partition error"
        executeOnWin "wmic partition get NumberOfBlocks | findstr "62513152"" || \
            quit "Unexpected partition" "ePC partition 3 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=$(( 32016171008 / 512 ))  # 62531584 Sectors
        PART_SIZE=62513152
    else
        quit "ePC SSD Size mismatch" "" "" "ePC SSD Size" "mismatch"
    fi
    echo $PART_POS
    echo $PART_SIZE
    pretty "Checking preconditions" "done." "" "Checking preconditions" "done."
}


check_preconditions_lin() {
    pretty "Checking preconditions..." "" "" "Checking" "preconditions..."
    if [ $SSD_SIZE -eq 32 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 42049536" || quit "Unexpected partition" "ePC partition 5 is not at" "expected position, update failed." "Update failed." "partition error"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 20482422" || quit "Unexpected partition" "ePC partition 5 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=42049536
        PART_SIZE=20482422
    elif [ $SSD_SIZE -eq 64 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 62531584" || quit "Unexpected partition" "ePC partition 5 is not at" "expected position, update failed." "Update failed." "partition error"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 62513152" || quit "Unexpected partition" "ePC partition 5 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=62531584
        PART_SIZE=62513152
    elif [ $SSD_SIZE -eq 120 ]; then
        pretty "ePC SSD Size" "$SSD_SIZE GB" "" "ePC SSD Size" "$SSD_SIZE GB"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 62531584" || quit "Unexpected partition" "ePC partition 5 is not at" "expected position, update failed." "Update failed." "partition error"
        executeAsRoot "sfdisk -d /dev/sda | grep sda5 | grep 62513152" || quit "Unexpected partition" "ePC partition 5 is not of" "expected size, update failed." "Update failed." "partition error"
        PART_POS=62531584
        PART_SIZE=62513152
    else
        quit "ePC SSD Size mismatch" "" "" "ePC SSD Size" "mismatch"
    fi
    pretty "Checking preconditions" "done." "" "Checking preconditions" "done."
}

switch_from_win_to_ubuntu() {
    pretty "Switching OS..." "win -> ubuntu" "" "Switching OS..." "win -> ubuntu"
    executeOnWin "mountvol p: /s & p: & cd nonlinear & del win & echo hello > linux & shutdown -r -t 0 -f" \
        || quit "Can't switch OS..." "Check failed." "" "Check failed." "OS switch fail"
    wait4response
    pretty "Switching OS..." "done." "" "Switching OS..." "done."
}

tear_down_playground() {
    pretty "Stopping C15 processes..." "" "" "Stopping C15" "processes..."
    systemctl stop playground
    systemctl stop bbbb
    pretty "Stopping C15 processes" "done." "" "Stopping C15" "processes done."
}

unmount_doomed() {
    pretty "Unmounting partitions..." "" "" "Unmounting partitions..." ""
    executeAsRoot "umount /boot/efi" || quit "Unmounting failed." "Unmounting /boot/efi failed," "update failed." "Update failed:" "umount failed."
    pretty "Unmounting partitions done." "" "" "Unmounting partitions" "done."
}

create_partitions() {
    pretty "Creating partitions..." "" "" "Creating partitions..." ""
    PART="label: gpt
          label-id: 7D22A5F5-C3A7-4C35-B879-B58C9B422919
          device: /dev/sda
          unit: sectors
          first-lba: 2048

          /dev/sda1 : start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=37946461-1176-43E6-9F0F-5B98652B8AB9
          /dev/sda2 : start=     1050624, size=    16777216, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=274A1E65-7546-4887-86DD-771BAC588588
          /dev/sda3 : start=    17827840, size=    16777216, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=E30DE52F-B006-442E-9A4A-F332A9A0FF00
          /dev/sda4 : start=    34605056, size=     7444480, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=22c47cae-cf10-11e9-b217-6b290f556266
          /dev/sda5 : start=   $PART_POS, size=  $PART_SIZE, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=45c5a8ae-cf10-11e9-aefa-5f647edf4354"
    
    executeAsRoot "echo \"$PART\" | sfdisk --no-reread /dev/sda" || quit "Partitioning failed." "Could not repartition the" "ePC SSD, update failed." "Update failed:" "Partitioning failed."
    executeAsRoot "partprobe" || quit "Partitioning" "Could not re-read the SSD" "partition table. Update failed" "Update failed:" "re-read part. table failed"
    executeAsRoot "mkfs.fat /dev/sda1" || quit "Partitioning" "Could not make filesystem." "Update failed." "Update failed:" "mkfs part 1 failed"
    executeAsRoot "mkfs.ext4 /dev/sda2" || quit "Partitioning" "Could not make filesystem." "Update failed." "Update failed:" "mkfs part 2 failed"
    executeAsRoot "mkfs.ext4 /dev/sda3" || quit "Partitioning" "Could not make filesystem." "Update failed." "Update failed:" "mkfs part 3 failed"
    executeAsRoot "mkfs.ext4 /dev/sda4" || quit "Partitioning" "Could not make filesystem." "Update failed." "Update failed:" "mkfs part 4 failed"
    pretty "Creating partitions done." "" "" "Creating partitions" "done."
}

copy_partition_content() {
    pretty "Copying..." "partitions content." "Mounting partition 3..." "Copying..." "mounting partition 3"
    executeAsRoot "mount /dev/sda3 /mnt" || quit "Copying failed." "Could not mount partition 3." "Update failed." "Update failed:" "mount part 3 failed"
    
    pretty "Copying..." "partitions content." "Chmod partition 3..." "Copying..." "chmod partition 3"
    executeAsRoot "chmod 777 /mnt" || quit "Copying failed." "Could not chmod partition 3." "Update failed." "Update failed:" "chmod part 3 failed"
    
    print_scp_progress "1" ./p1.raw.gz /mnt/p1.raw.gz &
    $SSHPASS_PATH/sshpass -p 'sscl' scp ./p1.raw.gz sscl@$IP:/mnt || quit "Copying failed." "Could not copy p1.raw.gz." "Update failed." "Update failed:" "copy part 1 failed"
    
    print_scp_progress "2" ./p2.raw.gz /mnt/p2.raw.gz &
    $SSHPASS_PATH/sshpass -p 'sscl' scp ./p2.raw.gz sscl@$IP:/mnt || quit "Copying failed." "Could not copy p2.raw.gz." "Update failed." "Update failed:" "copy part 2 failed"

    pretty "Copying..." "partitions content done." "" "Copying..." "partitions done."
}

dd_partitions() {
    print_dd_progress "1" /tmp/dd1.log &
    executeAsRoot "cat /mnt/p1.raw.gz | gzip -d - | dd of=/dev/sda1 bs=1M status=progress" > /tmp/dd1.log 2>&1  || quit "Dumping failed." "Could not dump partition 1." "Update failed." "Update failed:" "dd /dev/sda1 failed"
    rm /tmp/dd1.log
    
    print_dd_progress "2" /tmp/dd2.log &
    executeAsRoot "cat /mnt/p2.raw.gz | gzip -d - | dd of=/dev/sda2 bs=1M status=progress" > /tmp/dd2.log 2>&1 || quit "Dumping failed." "Could not dump partition 2." "Update failed." "Update failed:" "dd /dev/sda2 failed"
    rm /tmp/dd2.log

    pretty "Dumping..." "done." "" "Dumping done." "" 
}

unmount_tmp() {
    pretty "Unmounting..." "temporary storage ..." "" "Unmounting" "tmp"
    executeAsRoot "umount /mnt" || quit "Unmounting failed." "Could not unmount temporary" "storage at /mnt. Update failed." "Update failed:" "umount /mnt failed"
    executeAsRoot "chmod 777 /mnt" || quit "Changing mode failed." "Could not change permissions" " of /mnt. Update failed." "Update failed:" "chmod /mnt"
    pretty "Unmounting..." "temporary storage" "done." "Unmounting" "tmp done."
}

copy_partition_3_content() {
    pretty "Copying..." "...partition 3 content" "to temporary storage." "Copying" "partition 3."
    print_scp_progress "3" ./p3.raw.gz /mnt/p3.raw.gz &
    $SSHPASS_PATH/sshpass -p 'sscl' scp ./p3.raw.gz sscl@$IP:/mnt || quit "Copying failed." "Could not copy partition 3" "content onto device. Update failed" "Update Failed:" "copy part 3 failed"
    pretty "Copying..." "...partition 3 content" "done." "Copying" "part 3 done."
}

dd_partition_3() {
    print_dd_progress "3" /tmp/dd3.log &
    executeAsRoot "cat /mnt/p3.raw.gz | gzip -d - | dd of=/dev/sda3 bs=1M status=progress" > /tmp/dd3.log 2>&1 || quit "Dumping failed." "Could not dd partition 3." "Update failed." "Update failed:" "dump part 3 failed"
    rm /tmp/dd3.log
    pretty "Dumping partition 3..." "...done." "" "Dumping part. 3..." "...done." 
}

install_grub() {
    pretty "Finalization..." "...mounting partition" "/dev/sda2" "Finalization..." "...mounting." 
    executeAsRoot "mount /dev/sda2 /mnt" || quit "Finalization failed" "Could not mount partition 2" "for installing grub. Update failed." "Update failed:" "mount sda2 failed"
    pretty "Finalization..." "...mounting partition" "/dev/sda1" "Finalization..." "...mounting." 
    executeAsRoot "mount /dev/sda1 /mnt/boot/" || quit "Finalization failed" "Could not mount partition 1" "for installing grub. Update failed." "Update failed:" "mount sda1 failed"
    pretty "Finalization..." "...mounting partition" "/dev" "Finalization..." "...mounting." 
    executeAsRoot "mount --rbind /dev /mnt/dev" || quit "Finalization failed" "Could not mount /dev" "for installing grub. Update failed." "Update failed:" "mount /dev failed"
    pretty "Finalization..." "...mounting partition" "/sys" "Finalization..." "...mounting." 
    executeAsRoot "mount --rbind /sys /mnt/sys" || quit "Finalization failed" "Could not mount /sys" "for installing grub. Update failed." "Update failed:" "mount /sys failed"
    pretty "Finalization..." "...mounting partition" "/proc" "Finalization..." "...mounting." 
    executeAsRoot "mount --rbind /proc /mnt/proc" || quit "Finalization failed" "Could not mount /proc" "for installing grub. Update failed." "Update failed:" "mount /proc failed"
    pretty "Finalization..." "...installing grub." "(1/2)" "Finalization..." "...installing grub." 
    executeAsRoot "chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck" || quit "Finalization failed" "Could not install grub." "Update failed." "Update failed:" "grub-install failed"
    pretty "Finalization..." "...installing grub." "(2/2)" "Finalization..." "...installing grub." 
    executeAsRoot "chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg" || quit "Finalization failed" "Could not install grub." "Update failed." "Update failed:" "grub-mkconfig failed"
    pretty "Finalization..." "...make cpio." "" "Finalization..." "...make cpio." 
    executeAsRoot "chroot /mnt mkinitcpio -p linux-rt" || quit "Finalization failed" "Could not make cpio." "Update failed." "Update failed:" "mkinitcpio failed"
    pretty "Finalization done." "" "" "Finalization done." "" 
}

merge_partitions() {
    pretty "Clean up..." "...merging partitions." "" "Clean up..." "...merging."
    executeAsRoot "reboot"
    wait4response
    pretty "Switching OS..." "done." "" "Switching OS..." "done."

    executeAsRoot "sfdisk --delete /dev/sda 4" || quit "" "Failed clean up!" "del_sda4" "Failed clean up!" "del_sda4"
    executeAsRoot "sfdisk --delete /dev/sda 5" || quit "" "Failed clean up!" "del_sda5" "Failed clean up!" "del_sda5"
    executeAsRoot "echo \";\" | sfdisk -a --no-reread /dev/sda" || quit "" "Failed clean up!" "mk_part" "Failed clean up!" "mk_part"
    executeAsRoot "echo \"y\" | mkfs.ext4 /dev/sda4" || quit "" "Failed clean up!" "mkfs" "Failed clean up!" "mkfs"
    pretty "Clean up..." "...done." "" "Clean up..." "...done."
}

reboot_device() {
    pretty "Rebooting ePC..." "Please wait a while" "the ePC is rebooting." "Rebooting ePC..." "Please wait."
    executeAsRoot "reboot"
    wait4response
    pretty "" "Your C15 has been" "successfully upgraded!" "Your C15 has been" "successfully upgraded."
}

start_playground() {
    systemctl start bbbb
    systemctl start playground
}

main() {
    pretty "Starting upgrade..." "" "" "Starting upgrade..." ""
    sleep 2
    pretty "Do NOT turn off" "till complete..." "" "Do NOT turn off" "till complete..."
    sleep 3

    check_connection
    get_hdw_info
    check_preconditions_win
    switch_from_win_to_ubuntu
    tear_down_playground
    unmount_doomed
    create_partitions
    copy_partition_content
    dd_partitions
    unmount_tmp
    copy_partition_3_content
    dd_partition_3
    install_grub
    merge_partitions
    reboot_device
    start_playground
    exit 0
}

main









