#!/bin/sh

set -x

BASE_DIR=$(dirname "$0")

source ${BASE_DIR}/bbb-tools.sh

BBB_REV=$(bbb_get_rev)

MMC_ROOT_PARTITION=$(bbb_get_mmc_root_partition)
MMC_DEVICE=$(bbb_get_mmc_dev)
MMC_MOUNT_POINT="$(bbb_get_mmc_mountpoint)"
if [ "${MMC_MOUNT_POINT}" = "" ]; then
	MMC_MOUNT_POINT="/tmp/mmc"
fi

EMMC_ROOT_PARTITION=$(bbb_get_emmc_root_partition)
EMMC_DEVICE=$(bbb_get_emmc_dev)
EMMC_MOUNT_POINT="$(bbb_get_emmc_mountpoint)"
if [ "${EMMC_MOUNT_POINT}" = "" ]; then
	EMMC_MOUNT_POINT="/tmp/emmc"
fi
EMMC_NEW_UUID="ea9ed055-84c5-4c76-b8c3-aba0b9eeb083"

SFDISK_CMD_STRING=",,L,\n"
DO_BACKUP=true

printf "\n"
printf "BBB Rev:         %s\n" ${BBB_REV}
printf "EMMC Device:     %s\n" ${EMMC_DEVICE}
printf "EMMC Root Part.: %s\n" ${EMMC_ROOT_PARTITION}
printf "EMMC Mountpoint: %s\n" ${EMMC_MOUNT_POINT}
printf "MMC Device:      %s\n" ${MMC_DEVICE}
printf "MMC Root Part.:  %s\n" ${MMC_ROOT_PARTITION}
printf "MMC Mountpoint:  %s\n" ${MMC_MOUNT_POINT}
printf "\n"

# 0: Prepare some stuff
#######################
printf "0: Preparing mmc and emmc for changes..."
mkdir -p ${EMMC_MOUNT_POINT} ${MMC_MOUNT_POINT}
systemctl disable internalstorage.mount
sync
printf "Done\n"

# 1: Backup all data we might have on emmc to mmc
#################################################
if [ "${DO_BACKUP}" = true ]; then
	bbb_mount_if_unmounted ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION} ${EMMC_MOUNT_POINT}
	if [ -d ${EMMC_MOUNT_POINT}/preset-manager ]; then
		printf "1: Backup data from emmc to mmc..."

		if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
			bbb_mount_if_unmounted ${MMC_DEVICE}p${MMC_ROOT_PARTITION} ${MMC_MOUNT_POINT}
		fi

		cp -Rf ${EMMC_MOUNT_POINT}/preset-manager ${MMC_MOUNT_POINT}

		if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
			bbb_unmount_if_mounted ${MMC_MOUNT_POINT}
		fi

		printf "Done\n"
	else
		DO_BACKUP=false
	fi
	bbb_unmount_if_mounted ${EMMC_MOUNT_POINT}
fi


# 2: Rewrite partition on emmc
##############################
printf "2: Write new partition table to emmc..."
bbb_unmount_if_mounted ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION}
wipefs -a ${EMMC_DEVICE}
echo -e ${SFDISK_CMD_STRING} | sfdisk --force ${EMMC_DEVICE}
sync
EMMC_ROOT_PARTITION=1 # Starting from here, rootpart is 1
yes | mkfs.ext3 -U ${EMMC_NEW_UUID} ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION}
hdparm -z "${EMMC_DEVICE}"
printf "Done\n"

# 3: Update bootloader
######################
printf "3: Update bootloader..."
[[ -f ${BASE_DIR}/MLO ]] || error "Can not find ${BASE_DIR}/MLO!"
[[ -f ${BASE_DIR}/u-boot.img ]] || error "Can not find ${BASE_DIR}/u-boot.img"
dd if=${BASE_DIR}/MLO of=${EMMC_DEVICE} bs=512 seek=256 count=256 conv=notrunc
sync
dd if=${BASE_DIR}/u-boot.img of=${EMMC_DEVICE} bs=512 seek=768 count=1024 conv=notrunc
sync
printf "Done.\n"

# 4: Restore backup
###################
if [ "${DO_BACKUP}" = true ]; then
	printf "4: Restoring backup..."
	bbb_mount_if_unmounted ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION} ${EMMC_MOUNT_POINT}

	if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
		bbb_mount_if_unmounted ${MMC_DEVICE}p${MMC_ROOT_PARTITION} ${MMC_MOUNT_POINT}
	fi

	mv ${MMC_MOUNT_POINT}/preset-manager ${EMMC_MOUNT_POINT}
	sync

	if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
		bbb_unmount_if_mounted ${MMC_MOUNT_POINT}
	fi

	bbb_unmount_if_mounted ${EMMC_MOUNT_POINT}
	printf "Done.\n"
fi

cp -v ${BASE_DIR}/internalstorage.mount /etc/systemd/system/internalstorage.mount
echo "cp -v ${BASE_DIR}/internalstorage.mount /etc/systemd/system/internalstorage.mount"
systemctl enable internalstorage.mount

