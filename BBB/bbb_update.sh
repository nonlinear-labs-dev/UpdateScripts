#!/bin/sh

CURRENT_DIR="$PWD"

# sshpass
if [ ! -x  /nonlinear/utilities/sshpass ]; then
    if [ ! -d "/nonlinear/utilities"  ]; then
        mkdir /nonlinear/utilities
    fi
    cp $CURRENT_DIR/BBB/utilities/sshpass /nonlinear/utilities/
    chmod +x /nonlinear/utilities/sshpass
    rm /root/.ssh/known_hosts
fi

# time.sh
grep 'system_linux' /nonlinear/scripts/time.sh &> /dev/null
SYSTEM_LINUX=$?

if [ ! -e /nonlinear/scripts/time.sh  ] || [ $SYSTEM_LINUX -ne 0 ]; then
    systemctl stop gettimefromepc.service

    rm -f /nonlinear/scripts/time.sh
    cp $CURRENT_DIR/BBB/scripts/time.sh /nonlinear/scripts/time.sh
    chmod +x /nonlinear/scripts/time.sh

    systemctl restart gettimefromepc.service
fi

# services
chmod 0644  $CURRENT_DIR/BBB/services/bbbb.service
cp -af   $CURRENT_DIR/BBB/services/bbbb.service  /etc/systemd/system/bbbb.service
ln -nfs  /etc/systemd/system/bbbb.service /etc/systemd/system/multi-user.target.wants/bbbb.service


chmod 0644 $CURRENT_DIR/BBB/services/playground.service
cp -af  $CURRENT_DIR/BBB/services/playground.service  /etc/systemd/system/playground.service
ln -nfs /etc/systemd/system/playground.service /etc/systemd/system/multi-user.target.wants/playground.service

systemctl daemon-reload

# playground
VERSION=`date +"%Y-%m-%d-%H-%M"`

chmod 0755 $CURRENT_DIR/BBB/playground/resources/pack-journal.sh
chmod 0755 $CURRENT_DIR/BBB/playground/playground
chmod 0755 $CURRENT_DIR/BBB/playground/bbbb
chmod +x $CURRENT_DIR/BBB/playground/playground
chmod +x $CURRENT_DIR/BBB/playground/bbbb

cp -arf $CURRENT_DIR/BBB/playground /nonlinear/playground-$VERSION
rm /nonlinear/playground
mv /nonlinear/playground /nonlinear/playground-old
ln -nfs /nonlinear/playground-$VERSION /nonlinear/playground
