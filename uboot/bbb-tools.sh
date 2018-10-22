#!/bin/sh

# Current values are: A5A 0C0
bbb_get_rev() {
	hexdump -e '8/1 "%c"' "/sys/bus/i2c/devices/0-0050/eeprom" -s 13 -n 3
}

# usage: bbb_get_mountpoint /dev/mmcblk1p1
bbb_get_mountpoint() {
	mount | grep "$1" | cut -d ' ' -f3
}

# Returns /dev/mmcblk{0,1}
bbb_get_emmc_dev() {
	EMMC_DEVICE=""
	for d in "/dev/mmcblk1" "/dev/mmcblk0"; do
	        if [ -b ${d}boot0 ]; then
	                EMMC_DEVICE=${d}
	        fi
	done
	echo "${EMMC_DEVICE}"
}

# Returns {1,2}
bbb_get_emmc_root_partition() {
	EMMC_DEV=$(bbb_get_emmc_dev)
	if [ -b "${EMMC_DEV}p2" ]; then
		echo "2"
		return 0
	fi
	echo "1"
}
# Returns a path or an empty string
bbb_get_emmc_mountpoint() {
	EMMC_DEV=$(bbb_get_emmc_dev)
	bbb_get_mountpoint ${EMMC_DEV}
}

# Returns {1,2}
bbb_get_mmc_root_partition() {
	MMC_DEV=$(bbb_get_mmc_dev)
	if [ -b "${MMC_DEV}p2" ]; then
		echo "2"
		return 0
	fi
	echo "1"
}

# Returns /dev/mmcblk{0,1}
bbb_get_mmc_dev() {
	MMC_DEVICE=""
	for d in "/dev/mmcblk1" "/dev/mmcblk0"; do
	        if ! [ -b ${d}boot0 ]; then
	                MMC_DEVICE=${d}
	        fi
	done
	echo "${MMC_DEVICE}"
}

# Returns a path or an empty string
bbb_get_mmc_mountpoint() {
	MMC_DEV=$(bbb_get_mmc_dev)
	bbb_get_mountpoint ${MMC_DEV}
}

error() {
	printf "\nERROR (%s)\n" "$1" >&2
	exit
}

#usage: bbb_is_mounted /dev/mmcblk1p1
bbb_is_mounted() {
	if [ "$(mount | grep $1)" = "" ]; then
		return 0
	else
		return 1
	fi
}

#usage: bbb_mount_if_unmounted /dev/mmcblk0p1 /tmp/emmc
bbb_mount_if_unmounted() {
	if [ "$(mount | grep $1)" = "" ]; then
		mount "$1" "$2" || error "Can not mount $1 at $2"
	fi
}

#usage: bbb_unmount_if_mounted /dev/mmcblk0p1
bbb_unmount_if_mounted() {
	if ! [ "$(mount | grep $1)" = "" ]; then
		umount "$1" || error "Can not umount $1"
	fi
}

