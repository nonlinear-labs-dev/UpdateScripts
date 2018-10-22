#!/bin/sh

BASE_DIR=$(dirname "$0")

source ${BASE_DIR}/bbb-tools.sh

BOOTLOADER_DIR="${BASE_DIR}"
LOGFILE_STDERR="$0.stderr.log"
LOGFILE_STDOUT="$0.stdout.log"

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

echo "######################################################################" >> ${LOGFILE_STDERR}
echo "######################################################################" >> ${LOGFILE_STDOUT}

printf "\n"
printf "Logfile stderr:  %s\n" ${LOGFILE_STDERR}
printf "Logfile stdout:  %s\n" ${LOGFILE_STDOUT}
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
mkdir -p ${EMMC_MOUNT_POINT} ${MMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}
sync
printf "Done\n"

# 1: Backup all data we might have on emmc to mmc
#################################################
if [ "${DO_BACKUP}" = true ]; then
	bbb_mount_if_unmounted ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION} ${EMMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}
	if [ -d ${EMMC_MOUNT_POINT}/preset-manager ]; then
		printf "1: Backup data from emmc to mmc..."

		if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
			bbb_mount_if_unmounted ${MMC_DEVICE}p${MMC_ROOT_PARTITION} ${MMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}
		fi

		cp -Rf ${EMMC_MOUNT_POINT}/preset-manager ${MMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not backup preset-manager"

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
wipefs -a ${EMMC_DEVICE} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not wipefs on ${EMMC_DEVICE}"
echo -e ${SFDISK_CMD_STRING} | sfdisk --force ${EMMC_DEVICE} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not create new partition table"
sync
yes | mkfs.ext3 -U ${EMMC_NEW_UUID} ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not create new ext3 filesystem"
hdparm -z "${EMMC_DEVICE}" 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}
printf "Done\n"


# 3: Update bootloader
######################
printf "3: Update bootloader..."
[[ -f ${BOOTLOADER_DIR}/MLO ]] || error "Can not find ${BOOTLOADER_DIR}/MLO!"
[[ -f ${BOOTLOADER_DIR}/u-boot.img ]] || error "Can not find ${BOOTLOADER_DIR}/u-boot.img"
dd if=${BOOTLOADER_DIR}/MLO of=${EMMC_DEVICE} bs=512 seek=256 count=256 conv=notrunc 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not diskdump MLO on ${EMMC_DEVICE}"
sync
dd if=${BOOTLOADER_DIR}/u-boot.img of=${EMMC_DEVICE} bs=512 seek=768 count=1024 conv=notrunc 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not diskdump u-boot.bon on ${EMMC_DEVICE}"
sync
printf "Done.\n"

# 4: Restore backup
###################
if [ "${DO_BACKUP}" = true ]; then
	printf "4: Restoring backup..."
	bbb_mount_if_unmounted ${EMMC_DEVICE}p${EMMC_ROOT_PARTITION} ${EMMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}

	if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
		bbb_mount_if_unmounted ${MMC_DEVICE}p${MMC_ROOT_PARTITION} ${MMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR}
	fi

	cp -Rf ${MMC_MOUNT_POINT}/preset-manager ${EMMC_MOUNT_POINT} 1>>${LOGFILE_STDOUT} 2>>${LOGFILE_STDERR} || error "Can not restore backup from ${MMC_MOUNT_POINT}"
	rm -Rf ${MMC_MOUNT_POINT}/preset-manager || error "Can not remote backup from ${MMC_MOUNT_POINT}"
	sync

	if ! [ "${MMC_MOUNT_POINT}" = "/" ]; then
		bbb_unmount_if_mounted ${MMC_MOUNT_POINT}
	fi

	bbb_unmount_if_mounted ${EMMC_MOUNT_POINT}
	printf "Done.\n"
fi


