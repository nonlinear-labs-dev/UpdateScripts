# C15 Win2Lin Upgrade (Master 1.7)

The upgrade is based on the scripts from the C15 Project (C15/build-tools/create-c15-update/).
The run.sh script additionally checks the following in the epc_upgrade function
- can Windows be ssh-ed from the BBB at all
- is Pascal's nonlinear bootloader installed
- is nonlinear-c15-major-upgrade.tar present on the stick
- is enough space on the USB sitck (the upgrade is going to be unpacked on the stick, since the BBB soes not offer enough space)
- is the USB stick format 'vfat'
- is the major upgrade corrupt

After the check the 'upgrade50Plus.sh' carries out the upagrde. If any of these steps fail, the C15 will prompt the User that the Upgrade failed. If successful the update to the current 1.7 master is carried out. The 

## Creating the ePC Partitions and the upgrade.tar 
1) In the C15 Project switch BUILD_EPC=ON and select the target --epc-nonlinux-vm-installation
This will create a 'disk.vmdk' file in your previously specified 'build' directory und '/build-tools/epc/'

2) cd into the directory with the 'vmdk' file and convert it into a raw image using
Starting from here, you should make sure to have enough space on your system.
```
vboxmanage clonehd --format RAW /path/to.vmdk ./NonLinuxSSD.raw
```
3) Mount the raw image into the host system
```
sudo losetup -f -P --show ./NonLinuxSSD.raw
```
5) Mount every partition, clean it with zeros (dirty but efficient), extract and zip them up.
These should now be small enough to be deployed onto the BBB
```
sudo mount /dev/loop0pN /mnt
sudo dd if=/dev/zero of=/mnt/tmpzero.txt
sudo rm /mnt/tmpzero.txt
sudo umount /dev/loop0pN
sudo dd if=/dev/loop0pN bs=1M status=progress | gzip > pN.raw.gz
```
NOTE: You will only need to do this for the first three partitions! The fourth paprtition is empty anyway and will be adjusted during the upgrade!

6) Deploy the three partition zips into the 'nonlinear-c15-major-upgrade' folder, where the 'upgrade50Plus.sh' should be and create a tar. named *win2lin.tar*
Create a checksum file, with the sum being the name of the file. Create a further .tar containing *win2*lin.tar* and the checksum file and name it *nonlinear-c15-major-upgrade.tar*

7) copy *nonlinear-c15-update.tar* and *nonlinear-c15-major-upgrade.tar* onto a fat32/vfat Usb Stick, which should habe 4 GB Free space next to the to files and you are ready to go!
