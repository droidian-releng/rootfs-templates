#!/bin/bash

set -e

ROOTFS_PATH=$(find ${PWD} -maxdepth 1 -mindepth 1 -type d -name '.debos-*' -printf '%T@ %p\n' | sort -nr | head -n 1 | awk '{ print $2 }')/root
ROOTFS_SIZE=$(du -sm $ROOTFS_PATH | awk '{ print $1 }')

ZIP_NAME=${1}
WORK_DIR=${ZIP_NAME}.work
IMG_SIZE=$(( ${ROOTFS_SIZE} + 250 + 32 + 32 )) # FIXME 250MB + 32MB + 32MB contingency
IMG_MOUNTPOINT=".image"

clean() {
	rm -rf ${WORK_DIR}
}
trap clean EXIT

# Crate temporary directory
mkdir ${ZIP_NAME}.work

# create target base image
echo "Creating empty image"
dd if=/dev/zero of=${WORK_DIR}/userdata.raw bs=1M count=${IMG_SIZE}

# Loop mount
echo "Mounting image"
DEVICE=$(losetup -f)

losetup ${DEVICE} ${WORK_DIR}/userdata.raw

# Create LVM physical volume
echo "Creating PV"
pvcreate ${DEVICE}

# Create LVM volume group
echo "Creating VG"
vgcreate droidian "${DEVICE}"

# Create LVs, currently
# 1) droidian-persistent (32M)
# 2) droidian-reserved (32M)
# 3) droidian-rootfs (rest)
echo "Creating LVs"
lvcreate --zero n -L 32M -n droidian-persistent droidian
lvcreate --zero n -L 32M -n droidian-reserved droidian
lvcreate --zero n -l 100%FREE -n droidian-rootfs droidian

vgchange -ay droidian
vgscan --mknodes -v

sleep 5

# Try to determine the real device. vgscan --mknodes would have
# created the links as expected, but our /dev won't actually have
# the device mapper devices since they appeared after the container
# start.
# A workaround for that (see moby#27886) is to bind mount the host's /dev,
# but since we start systemd as well this might/will create issues with
# the host system.
# We workaround that by bind-mounting /dev to /host-dev, so that the host's
# /dev is still available, but we need to determine the correct path
# by ourselves
ROOTFS_VOLUME=$(realpath /dev/mapper/droidian-droidian--rootfs)
ROOTFS_VOLUME=${ROOTFS_VOLUME/\/dev/\/host-dev}

# Create rootfs filesystem
echo "Creating rootfs filesystem"
mkfs.ext4 -O ^metadata_csum -O ^64bit ${ROOTFS_VOLUME}

# mount the image
echo "Mounting root image"
mkdir -p $IMG_MOUNTPOINT
mount ${ROOTFS_VOLUME} ${IMG_MOUNTPOINT}

# copy rootfs content
echo "Syncing rootfs content"
rsync --archive -H -A -X ${ROOTFS_PATH}/* ${IMG_MOUNTPOINT}
rsync --archive -H -A -X ${ROOTFS_PATH}/.[^.]* ${IMG_MOUNTPOINT}
sync

# Create stamp file
mkdir -p ${IMG_MOUNTPOINT}/var/lib/halium
touch ${IMG_MOUNTPOINT}/var/lib/halium/requires-lvm-resize

# umount the image
echo "umount root image"
umount ${IMG_MOUNTPOINT}

# clean up
vgchange -an droidian

losetup -d ${DEVICE}

img2simg ${WORK_DIR}/userdata.raw ${WORK_DIR}/userdata.img
rm -f ${WORK_DIR}/userdata.raw

# Prepare target zipfile
echo "Preparing zipfile"
cp -R android-image-flashing-template/template ${WORK_DIR}/target
mv ${WORK_DIR}/userdata.img ${WORK_DIR}/target/data/userdata.img

# Copy kernel and stuff
bootimage=$(find ${ROOTFS_PATH}/boot -iname boot.img* -type f | head -n 1)
dtbo=$(find ${ROOTFS_PATH}/boot -iname dtbo.img* -type f | head -n 1)
vbmeta=$(find ${ROOTFS_PATH}/boot -iname vbmeta.img* -type f | head -n 1)

cp "${bootimage}" ${WORK_DIR}/target/data/boot.img
[ -e "${dtbo}" ] && cp "${dtbo}" ${WORK_DIR}/target/data/dtbo.img
[ -e "${vbmeta}" ] && cp "${vbmeta}" ${WORK_DIR}/target/data/vbmeta.img

kernel_version=$(basename ${bootimage})
kernel_version=${kernel_version/boot.img-//}

cat \
	${ROOTFS_PATH}/usr/lib/flash-bootimage/flash-bootimage.conf \
	${ROOTFS_PATH}/usr/lib/flash-bootimage/${kernel_version}.conf \
	> ${WORK_DIR}/target/data/device-configuration.conf

# generate zip
echo "Generating zip"
(cd ${WORK_DIR}/target ; zip -r9 ../../$ZIP_NAME * -x .git README.md *placeholder)

echo "done."
