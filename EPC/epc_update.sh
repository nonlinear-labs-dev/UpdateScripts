#!/bin/sh

TIMEOUT=60
EPC_IP=192.168.10.10
CURRENT_PATH="$PWD"

executeAsRoot() {
    rm /root/.ssh/known_hosts 1>&2 > /dev/null;
    echo "sscl" | /nonlinear/utilities/sshpass -p 'sscl' ssh -o ConnectionAttempts=1 -o ConnectTimeout=1 -o StrictHostKeyChecking=no sscl@$EPC_IP \
        "sudo -S /bin/bash -c '$1' 1>&2 > /dev/null"
    return $?
}

wait4response() {
    COUNTER=0
    while true; do
        executeAsRoot "exit"
        [ $? -eq 0 ] && break

        sleep 1
        ((COUNTER++))
        echo "awaiting reboot ... $COUNTER/$TIMEOUT"
        [ $COUNTER -eq $TIMEOUT ] && { report_and_quit "E45 ePC update: Reboot taking too long... timed out" "45"; break; }
    done
}

kill $(pidof python)
cd $CURRENT_PATH/EPC
rm ./server.log
touch ./server.log
python -m SimpleHTTPServer 8000 &> ./server.log & PYTHON_PID=$!
executeAsRoot "sudo reboot"
wait4response
kill "${PYTHON_PID}" &> /dev/null
if cat ./server.log | grep "GET /update.tar HTTP/1.1"; then
   rm ./server.log
   echo "ePC update successfull ..."
fi
