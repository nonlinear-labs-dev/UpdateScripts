#! /bin/sh

IP=192.168.10.10
TIMEOUT=120
COUNTER=0
SSHPASS_PATH="/nonlinear/utilities"

executeAsRoot() {
    echo "$1"
    echo "sscl" | $SSHPASS_PATH/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$IP "sudo -S /bin/bash -c '$2'" &> /dev/null
    return $?
}

echo "Back to Windows!"
rm /root/.ssh/known_hosts &> /dev/null
executeAsRoot "Mounting ..." "mount /dev/sda2 /mnt" || { echo "Can't mount! Aborting ..."; exit 1; }
executeAsRoot "Removing ..." "rm /mnt/nonlinear/linux" || { echo "Can't remove! Aborting ..."; exit 1; }
executeAsRoot "Touching ..." "touch /mnt/nonlinear/win" || { echo "Can't touch! Aborting ..."; exit 1; }
executeAsRoot "Unmouting ..." "umount /dev/sda2" || { echo "Can't unmount! Aborting ..."; exit 1; }
executeAsRoot "Rebooting ..." "reboot"


# timeout
while true; do
    rm /root/.ssh/known_hosts;
    $SSHPASS_PATH/sshpass -p 'TEST' ssh -o ConnectTimeout=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no TEST@$IP "exit"
    [ $? -eq 0 ] && break

    sleep 1
    ((COUNTER++))
    echo "$COUNTER / $TIMEOUT"
    [ $COUNTER -eq $TIMEOUT ] && { echo "Reboot taking too long... timed out"; break; }
done

exit 0



# for upgrade50plus.sh intergration
#switch_from_ubuntu_to_win() {
#    pretty "Switching OS..." "ubuntu -> win" "" "Switching OS..." "ubuntu -> win"
#    rm /root/.ssh/known_hosts &> /dev/null
#    executeAsRoot "mount /dev/sda2 /mnt" || quit "Can't switch OS..." "mount failed." "" "" "Can't switch OS..." "mount failed."
#    executeAsRoot "rm /mnt/nonlinear/linux" || quit "Can't switch OS..." "rm failed." "" "" "Can't switch OS..." "rm failed."
#    executeAsRoot "touch /mnt/nonlinear/win" || quit "Can't switch OS..." "touch failed." "" "" "Can't switch OS..." "touch failed."
#    executeAsRoot "umount /dev/sda2" || quit "Can't switch OS..." "umount failed." "" "" "Can't switch OS..." "umount failed."
#    executeAsRoot "reboot"

#    while true; do
#        rm /root/.ssh/known_hosts &> /dev/null;
#        if sshpass -p 'TEST' ssh -o StrictHostKeyChecking=no TEST@$IP "exit" &> /dev/null; then
#            break
#        fi
#        sleep 1
#    done
#    pretty "Switching OS..." "done." "" "Switching OS..." "done."
#}
