#!/bin/bash

usage() {
    echo "usage: ${0} -i </path/to/oetmp> [[-h <hostname>] [-s <card size in gb>] [-k <k3s Shared Key>] [-r <agent|server>] [-a <k3s server IP/hostname>]]"
}

OE_MACHINE=odroid-c2
OE_IMAGE=k3s
OE_IMAGE_FILE="${OE_IMAGE}-image-${OE_MACHINE}.tar.xz"
MOUNT_PATH="/media/card"
DSTDIR=$PWD/dist

# Defaults
HOSTNAME=k3s-master
SIZE_GB=8
K3S_PSK=changeme
K3S_ROLE=server
K3S_SERVER_ADDRESS=
OETMP=

while [ "$1" != "" ]; do
    case $1 in
        -i )    shift
                OETMP=$1
                ;;
        -h )    shift
                HOSTNAME=$1
                ;;
        -s )    shift
                SIZE_GB=$1
                ;;
        -k )    shift
                K3S_PSK=$1
                ;;
        -r )    shift
                K3S_ROLE=$1
                ;;
        -a )    shift
                K3S_SERVER_ADDRESS=$1
                ;;
        * )     usage
                exit 1
    esac
    shift
done

init() {

    if [ -z "${OETMP}" ]; then
        echo "Must specify OE temp path (-i </path/to/oetmp>)  "
        exit 1
    fi

    if [ "$K3S_ROLE" == "agent" ]; then
        if [ -z "${K3S_SERVER_ADDRESS}" ]; then
            echo "Must specify server address (-a <k3s server IP/hostname>)  "
            exit 1
        fi
    fi

    SRCDIR=${OETMP}/deploy/images/${OE_MACHINE}
    SDIMG=${OE_MACHINE}-${OE_IMAGE}-${K3S_ROLE}_${HOSTNAME}_${SIZE_GB}gb.img

    if [ ! -f "${SRCDIR}/${OE_IMAGE_FILE}" ]; then
        echo "File not found: ${SRCDIR}/${OE_IMAGE_FILE}"
        exit 1
    fi

    if [ ! -f ${SRCDIR}/bl1.bin.hardkernel ]; then
        echo "File not found: ${SRCDIR}/bl1.bin.hardkernel"
        exit 1
    fi

    if [ ! -f ${SRCDIR}/u-boot-${OE_MACHINE}.bin ]; then
        echo "File not found: ${SRCDIR}/u-boot-${OE_MACHINE}.img"
        exit 1
    fi

    if [ ! -d ${MOUNT_PATH} ]; then
        echo "Creating temporary mount point [${MOUNT_PATH}]"
        mkdir -p ${MOUNT_PATH}
    fi

    if [ ! -d ${DSTDIR} ]; then
        echo "Creating destination directory [${MOUNT_PATH}]"
        mkdir -p ${DSTDIR}
    fi

    if [ -f "${DSTDIR}/${SDIMG}" ]; then
        echo "Removing existing image: ${DSTDIR}/${SDIMG}"
        rm ${DSTDIR}/${SDIMG}
    fi

    if [ -f "${DSTDIR}/${SDIMG}.xz" ]; then
        echo "Removing existing image: ${DSTDIR}/${SDIMG}"
        rm -f ${DSTDIR}/${SDIMG}.xz*
    fi

    echo "Using Options:

    HOSTNAME=$HOSTNAME
    SIZE_GB=$SIZE_GB
    K3S_PSK=$K3S_PSK
    K3S_ROLE=$K3S_ROLE
    K3S_SERVER_ADDRESS=$K3S_SERVER_ADDRESS
    OETMP=$OETMP"
}

copy_boot() {
    local dev=$1
    if [ ! -b ${dev} ]; then
        echo "Block device not found: ${dev}"
        exit 1
    fi

    read -p "Continue to copy bootloader to device ${dev} (y/n)?" CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "Canceling copy bootloader"
        return 1
    fi

    echo "Using dd to copy bl1.bin.hardkernel to unpartitioned space"
    sudo dd if=${SRCDIR}/bl1.bin.hardkernel of=${dev} conv=notrunc bs=1 count=442
    sudo dd if=${SRCDIR}/bl1.bin.hardkernel of=${dev} conv=notrunc bs=512 skip=1 seek=1

    echo "Using dd to copy u-boot to unpartitioned space"
    sudo dd if=${SRCDIR}/u-boot-${OE_MACHINE}.bin of=${dev} conv=notrunc bs=512 seek=97
    echo "Done"
}

copy_rootfs() {
    local dev=$1
    echo "Formatting $dev as ext4"
    sudo mkfs.ext4 -q -F $dev

    echo "Mounting $dev"
    sudo mount $dev $MOUNT_PATH

    echo "Extracting ${SRCDIR}/${OE_IMAGE_FILE} to $MOUNT_PATH"
    sudo tar -C $MOUNT_PATH -xJf ${SRCDIR}/${OE_IMAGE_FILE}

    echo "Generating a random-seed for urandom"
    mkdir -p $MOUNT_PATH/var/lib/urandom
    sudo dd if=/dev/urandom of=$MOUNT_PATH/var/lib/urandom/random-seed bs=512 count=1
    sudo chmod 600 $MOUNT_PATH/var/lib/urandom/random-seed

    echo "Writing hostname to /etc/hostname"
    sudo bash -c 'echo "'"$HOSTNAME"'" > '"$MOUNT_PATH"'/etc/hostname'

    echo "Writing k3s config to /etc/default/k3s"
    sudo sed -i "s,K3S_CLUSTER_SECRET=.*,K3S_CLUSTER_SECRET=${K3S_PSK},g" ${MOUNT_PATH}/etc/default/k3s

    if [ "$K3S_ROLE" == "agent" ]; then
        sudo sed -i "s,K3S_URL=.*,K3S_URL=https://${K3S_SERVER_ADDRESS}:6443,g" ${MOUNT_PATH}/etc/default/k3s
        sudo sed -i "s,K3S_ARGS=.*,K3S_ARGS=agent,g" ${MOUNT_PATH}/etc/default/k3s
    fi
    echo "Have /etc/default/k3s content:"
    cat ${MOUNT_PATH}/etc/default/k3s

    if [ -f ./interfaces ]; then
        echo "Writing ./interfaces to ${MOUNT_PATH}/etc/network/"
        sudo cp ./interfaces ${MOUNT_PATH}/etc/network/interfaces
    fi

    if [ -f ./wpa_supplicant.conf ]; then
        echo "Writing ./wpa_supplicant.conf to ${MOUNT_PATH}/etc/"
        sudo cp ./wpa_supplicant.conf${MOUNT_PATH}/etc/wpa_supplicant.conf
    fi

    echo "Unmounting $dev"
    sudo umount $dev
    echo "Done"
}

sdcard_image() {
    echo "Creating the loop device"
    local loopdev=`losetup -f`

    echo "Creating an empty SD image file"
    dd if=/dev/zero of=${DSTDIR}/${SDIMG} bs=1G count=${SIZE_GB}

    echo "Partitioning the SD image"
    echo '8182,,,*' | sfdisk ${DSTDIR}/${SDIMG}

    echo "Attaching to the loop device"
    sudo losetup -P $loopdev ${DSTDIR}/${SDIMG}

    echo "Copying the boot partition"
    if ! copy_boot $loopdev; then
        sudo losetup -D
        echo "Aborting"
        exit 1
    fi

    echo "Copying the rootfs"
    if ! copy_rootfs ${loopdev}p1; then
        sudo losetup -D
        echo "Aborting"
        exit 1
    fi

    echo "Detatching loop device"
    sudo losetup -D

    echo "Compressing the SD card image"
    sudo xz -v -3 ${DSTDIR}/${SDIMG}

    echo "Creating md5sum"
    pushd ${DSTDIR}
    md5sum ${SDIMG}.xz > ${SDIMG}.xz.md5
    popd

    echo "Done"
}

init
sdcard_image
