#! /bin/sh

IP=192.168.10.10
TIMEOUT=120
COUNTER=0
SSHPASS_PATH="/nonlinear/utilities"

executeAsRoot() {
    echo "sscl" | $SSHPASS_PATH/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$IP "sudo -S /bin/bash -c '$2'" &> /dev/null
    return $?
}


echo "Back to Linux!"
rm /root/.ssh/known_hosts &> /dev/null

$SSHPASS_PATH/sshpass -p 'TEST' ssh -o ConnectTimeout=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no TEST@$IP \
    "mountvol p: /s & p: & cd nonlinear & del win & echo hello > linux & shutdown -r -t 0 -f" &> /dev/null \
    || { echo "Can't switch to Linux! Aborting Upgrade ..."; exit 1; }

# timeout
while true; do
    rm /root/.ssh/known_hosts;
    executeAsRoot "exit"
    [ $? -eq 0 ] && break

    sleep 1
    ((COUNTER++))
    echo "$COUNTER/ $TIMEOUT"
    [ $COUNTER -eq $TIMEOUT ] && { echo "Reboot taking too long... timed out"; break; }
done

exit 0
