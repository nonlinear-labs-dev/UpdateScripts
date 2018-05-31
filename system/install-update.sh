#!/bin/sh

#If this is the first BBB update? if the playground is just a directory and not a link, rename dir and create link
if [[ -L "/nonlinear/playground" ]]
then
    #playground is a link
    echo "playground structure is ok!"
else
    #playground is only a directory
    mv /nonlinear/playground /nonlinear/playground_first_install
    ln -s /nonlinear/playground_first_install /nonlinear/playground
fi


#Delete old Updates
if [ -d /update ]
then
	echo "deleting old updates!"
	rm -rf /update/*
else
	echo "creating update directory"
	mkdir /update
fi

#if tar is present on stick
if [ -e /mnt/usb-stick/nonlinear-c15-update.tar ]
then
    #stop the playground
    systemctl stop playground
	echo "copying tar from usb!"
	#copy the update-tar
	cp /mnt/usb-stick/nonlinear-c15-update.tar /update
	#force the rename of the tar to copied using cp and rm
	echo "renaming tar on usb"
	cp -f /mnt/usb-stick/nonlinear-c15-update.tar /mnt/usb-stick/nonlinear-c15-update.tar-copied
	rm -f /mnt/usb-stick/nonlinear-c15-update.tar
	echo "renamed tar"
	#change into update and untar the update
	cd /update
	echo "unpacking tar"
	tar xvf nonlinear-c15-update.tar
	echo "unpacked tar"
	#delete the tar-file
	echo "deleting tar"
	rm -f nonlinear-c15-update.tar
	echo "deleted tar"
	#make run.sh executable and run
	echo "starting run.sh"
	chmod +x /update/run.sh
	/bin/sh /update/run.sh
	echo "update finished"
  rm -rf /update/*
fi
