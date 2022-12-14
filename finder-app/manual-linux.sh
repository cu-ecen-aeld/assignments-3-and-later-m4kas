#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE mrproper
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig
    make -j4 ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE all
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE modules
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE dtbs
fi

echo "Adding the Image in outdir"
rm -f ${OUTDIR}/Image
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
ROOTFS_DIR=${OUTDIR}/rootfs
echo "Creating rootfs dir here: ${ROOTFS_DIR}"
mkdir -p ${ROOTFS_DIR}
cd ${ROOTFS_DIR}
mkdir bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir usr/bin usr/lib usr/sbin
mkdir var/log
echo "Chown the root directory"
sudo chown -R root:root *

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

# TODO: Configure busybox
echo "Configure busybox"
sudo make distclean
sudo make defconfig

# TODO: Make and install busybox
echo "Make and install busybox"
# Installing busybox, but making it via sudo and passing PATH from non-sudo user
# (where cross compiler path is defined)
sudo env "PATH=$PATH" make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${ROOTFS_DIR} install
cd ${ROOTFS_DIR}

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
echo "Add library dependencies to rootfs"
SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)
echo "Compiler sysroot is: ${SYSROOT}"

sudo cp -a ${SYSROOT}/lib64/ld-2.31.so lib64
sudo cp -a ${SYSROOT}/lib64/libm-2.31.so lib64
sudo cp -a ${SYSROOT}/lib64/libresolv-2.31.so lib64
sudo cp -a ${SYSROOT}/lib64/libc-2.31.so lib64

sudo cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib
sudo chown root:root lib/ld-linux-aarch64.so.1
sudo chown -h root:root lib/ld-linux-aarch64.so.1

sudo cp -a ${SYSROOT}/lib64/libm.so.6 lib64
sudo chown root:root lib64/libm.so.6
sudo chown -h root:root lib64/libm.so.6

sudo cp -a ${SYSROOT}/lib64/libresolv.so.2 lib64
sudo chown root:root lib64/libresolv.so.2
sudo chown -h root:root lib64/libresolv.so.2

sudo cp -a ${SYSROOT}/lib64/libc.so.6 lib64
sudo chown root:root lib64/libc.so.6
sudo chown -h root:root lib64/libc.so.6


# TODO: Make device nodes
echo "Make device nodes"
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/console c 5 1

# TODO: Clean and build the writer utility
echo "Clean and build the writer utility"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
echo "Copy the finder related scripts and executables to the /home directory on the target rootfs"
sudo chown root:root writer
sudo cp -a writer ${ROOTFS_DIR}/home

# TODO: Chown the root directory
# Done above

echo "Additional files copy"
sudo mkdir -p ${ROOTFS_DIR}/home/conf
sudo cp ${FINDER_APP_DIR}/conf/username.txt ${ROOTFS_DIR}/home/conf
sudo cp ${FINDER_APP_DIR}/conf/assignment.txt ${ROOTFS_DIR}/home/conf
sudo cp ${FINDER_APP_DIR}/finder.sh ${ROOTFS_DIR}/home
sudo cp ${FINDER_APP_DIR}/finder-test.sh ${ROOTFS_DIR}/home
sudo cp ${FINDER_APP_DIR}/autorun-qemu.sh ${ROOTFS_DIR}/home

# echo "Modules install"
# cd ${OUTDIR}/linux-stable
# sudo make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=${ROOTFS_DIR} modules_install

# TODO: Create initramfs.cpio.gz
echo "Create initramfs.cpio.gz"
cd ${ROOTFS_DIR}
rm -f ../initramfs.cpio.gz
find . | cpio -o -H newc -R root:root > ../initramfs.cpio
cd ..
sudo gzip initramfs.cpio
sudo chown root:root initramfs.cpio.gz
