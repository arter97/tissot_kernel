#!/bin/bash
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export PARTITION_SIZE=67108864

export OS="9.0.0"
export SPL="2019-04"

echo "kerneldir = $KERNELDIR"
echo "ramfs_source = $RAMFS_SOURCE"

RAMFS_TMP="/tmp/arter97-tissot-ramdisk"

echo "ramfs_tmp = $RAMFS_TMP"
cd $KERNELDIR

if [[ "${1}" == "skip" ]] ; then
	echo "Skipping Compilation"
else
	echo "Compiling kernel"
	cp defconfig .config
	make "$@" || exit 1
fi

echo "Building new ramdisk"
#remove previous ramfs files
rm -rf '$RAMFS_TMP'*
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
#copy ramfs files to tmp directory
cp -axpP $RAMFS_SOURCE $RAMFS_TMP
cd $RAMFS_TMP

#clear git repositories in ramfs
find . -name .git -exec rm -rf {} \;
find . -name EMPTY_DIRECTORY -exec rm -rf {} \;

sed -i -e s@ro.build.version.release.*@ro.build.version.release=${OS}@g \
       -e s@ro.build.version.security_patch.*@ro.build.version.security_patch=${SPL}-01@g prop.default

$KERNELDIR/ramdisk_fix_permissions.sh 2>/dev/null

cd $KERNELDIR
rm -rf $RAMFS_TMP/tmp/*

cd $RAMFS_TMP
find . | fakeroot cpio -H newc -o | gzip -9 > $RAMFS_TMP.cpio.gz
ls -lh $RAMFS_TMP.cpio.gz
cd $KERNELDIR

echo "Making new boot image"
mkbootimg \
    --kernel $KERNELDIR/arch/arm64/boot/Image.gz-dtb \
    --ramdisk $RAMFS_TMP.cpio.gz \
    --cmdline 'console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 androidboot.bootdevice=7824900.sdhci earlycon=msm_hsl_uart,0x78af000 buildvariant=user veritykeyid=id:5560e7863b4d8118c2f1b065595cf93bb2447992' \
    --base           0x80000000 \
    --pagesize       2048 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00f00000 \
    --tags_offset    0x00000100 \
    --os_version     $OS \
    --os_patch_level $SPL \
    --header_version 1 \
    -o $KERNELDIR/boot.img

GENERATED_SIZE=$(stat -c %s boot.img)
if [[ $GENERATED_SIZE -gt $PARTITION_SIZE ]]; then
	echo "boot.img size larger than partition size!" 1>&2
	exit 1
fi

echo "done"
ls -al boot.img
echo ""
