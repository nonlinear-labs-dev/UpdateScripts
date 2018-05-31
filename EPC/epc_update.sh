#!/bin/sh

#the origin and dest. filenames
origin="/update/EPC/Phase22Renderer.ens"
destination="/mnt/windows/Phase22Renderer.ens"
pingcount=100
#loop pinging to wait for the EPC to startup
while [ $pingcount -ne 0 ] ; do
  ping -c 1 192.168.10.10
  returncode=$?
  if [ $returncode -eq 0 ] ; then
      ((pingcount = 1))
  fi
  echo $((pingcount = pingcount - 1))
done
# when the host is reachable via ping-status is 0
if [ $returncode -eq 0 ]; then
  #create the mountpoint if nonexistent
  if [ ! -d "/mnt/windows" ]; then
    mkdir /mnt/windows
  fi
  #unmount to prevent "device is busy"
  if [ grep -qs '/mnt/windows' /proc/mounts ]; then
    umount /mnt/windows
  fi
  #mount the windows-drive
  mount.cifs //192.168.10.10/update /mnt/windows -o user=TEST,password=TEST
  #copy the ensemble
  cp "$origin" "$destination"
fi
