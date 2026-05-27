#!/bin/bash

source lib.sh

if [ $# -lt 3 ]; then
    echo Usage:
    echo "	$0 <input> <h1|d1> <type> [compress uboot]"
    echo
    echo "		input		- input image"
    echo "		h1|d1|d2|j80|j100|j200|j310|cma	- select controller"
    echo "		type		- partition type. supported: haos, armbian"
    echo "		compress	- 'compress' or 'no' output to zip"
    echo "		uboot		- path to u-boot binary (ignored for j310)"
    exit
fi

SOC_FAMILY="legacy"

if [[ "$2" == "h1" || "$2" == "j80" ]]; then
  DTS="meson-gxl-s905w-jethome-jethub-j80.dts"
  CNAME="j80"
elif [[ "$2" == "d1" || "$2" == "j100" ]]; then
  DTS="meson-axg-jethome-jethub-j100.dts"
  CNAME="j100"
elif [[ "$2" == "d2" || "$2" == "j200" ]]; then
  DTS="meson-sm1-jethome-jethub-j200.dts"
  CNAME="j200"
elif [[ "$2" == "cma" ]]; then
  DTS="meson-axg-jethome-jethub-j100.dts"
  CNAME="magicbox"
elif [[ "$2" == "j310" ]]; then
  DTS="meson-s7-jethub-j310.dts"
  CNAME="j310"
  SOC_FAMILY="s7"
else
  echo "ERROR: unknown controller"
  exit
fi

if [[ "$3" == "haos" ]]; then
  DTI="partition_haos.dtsi"
  CPART="haos"
elif [[ "$3" == "armbian" ]]; then
  if [[ "$SOC_FAMILY" == "s7" ]]; then
    DTI="partition_arm_j310.dtsi"
    CPART="armbian.s7"
  else
    DTI="partition_arm.dtsi"
    CPART="armbian"
  fi
else
  echo "ERROR: unknown partition table"
  exit
fi

if [[ "$4" == "compress" ]]; then
    COMPRESS=yes
fi

if [[ "$SOC_FAMILY" == "s7" ]]; then
    UBOOT=""
elif [[ -e "$5" ]]; then
    UBOOT="$5"
else
    echo "Error: u-boot binary did not found"
    exit 1
fi

echo "UBOOT set to ${UBOOT}"

[[ ! -e $1 ]] && echo No file found && exit
echo "Selected $CNAME controller with $CPART partition table"


INPUT=$(readlink -f $1)
TMP=$(mktemp -d)
DTB="$TMP/${DTS::-4}.dtb"
EXT="${INPUT:${#INPUT}-3:3}"
if [[ ".xz" == "${EXT}" ]]; then
    INPUTE="${INPUT::-3}"
    echo "Found compressed image. Decompress $INPUTE$EXT"
    INPUT="$TMP/$(basename $INPUTE)"
    xzcat "${INPUTE}${EXT}" >"$INPUT"
fi

mkdir -p output
OUTIMG=$(basename $INPUT)
OUEXT="${OUTIMG:${#OUTIMG}-4:4}"
if [[ ".img" == "${OUEXT}" ]]; then
    OUTIMGE="${OUTIMG::-4}"
    OUTIMG="${OUTIMGE}.burn${OUEXT}"
else
    OUTIMG="${OUTIMG}.burn"
fi

cp "dts/$DTS" "$TMP/$DTS"
cp "dts/$DTI" "$TMP/$DTI"
sed -i "s/partition.dtsi/$DTI/g" "$TMP/$DTS"

cpp -nostdinc -I dts -I dts/include -undef -x assembler-with-cpp "$TMP/$DTS" "$TMP/$DTS.preprocess"
dtc -I dts -O dtb -p 0x1000 -qqq "$TMP/$DTS.preprocess" -o "$DTB"
FDISK=$(/usr/sbin/fdisk -l "$INPUT" | grep -P -A 100 "Device.+Boot.+Start.+End.+Sectors.+Size.+Id.+Type" | sed -- "s/\*//g" | grep "$INPUT"| grep -v Extended)

echo +! Device	! Start	! End	! Sectors	! Size	! Id	! Type	!-
i=1
while read -r line; do
    read -r Device Start End Sectors Size Id Type <<<$line
    Device=$(echo $(basename $Device) | sed --  "s/$(basename $INPUT)//g")
    echo +! $Device	! $Start	! $End	! $Sectors	! $Size	! $Id	! $Type	!-
    extract_partition "$INPUT" $Start $Sectors "$TMP/part-$i.img"
    i=$((i + 1))
done <<< "$FDISK"

# For s7 armbian: prepend 2x 102 MiB recovery slots before ext4 rootfs so
# that the on-chip layout matches CONFIG_MBR_ROOTFS_OFFSET_EXTRA (204 MiB) in
# u-boot. Final part-1.img = recovery_a + recovery_b + ext4.
if [[ "$3" == "armbian" && "$SOC_FAMILY" == "s7" && -e "bins/$CNAME/recovery.fit" ]]; then
    SLOT_BYTES=$((102 * 1024 * 1024))
    echo "Prepending 2x recovery.fit (102 MiB each) to rootfs"
    cp "bins/$CNAME/recovery.fit" "$TMP/recovery_a.bin"
    cp "bins/$CNAME/recovery.fit" "$TMP/recovery_b.bin"
    truncate -s $SLOT_BYTES "$TMP/recovery_a.bin"
    truncate -s $SLOT_BYTES "$TMP/recovery_b.bin"
    cat "$TMP/recovery_a.bin" "$TMP/recovery_b.bin" "$TMP/part-1.img" > "$TMP/part-1.img.new"
    mv "$TMP/part-1.img.new" "$TMP/part-1.img"
    rm "$TMP/recovery_a.bin" "$TMP/recovery_b.bin"
fi

cp "bins/$CNAME/platform.conf" "$TMP"

cc -o $TMP/dtbTool dtbtools/dtbTool.c
$TMP/dtbTool -o "$TMP/_aml_dtb.PARTITION" "$TMP"

cp "bins/image.$CPART.cfg" "$TMP/image.cfg"
if [[ "$SOC_FAMILY" == "s7" ]]; then
    cp "bins/$CNAME/u-boot.bin" "$TMP/"
    cp "bins/$CNAME/u-boot.bin.sd.bin" "$TMP/"
    cp "bins/$CNAME/u-boot.bin.usb" "$TMP/"
    cp "bins/$CNAME/usb_flow.aml" "$TMP/"
    PACKER="./tools/aml_image_v2_packer_new.s7"
else
    echo cp "$UBOOT" "$TMP/u-boot.bin"
    cp "$UBOOT" "$TMP/u-boot.bin"
    cp "bins/$CNAME/DDR.USB" "$TMP"
    cp "bins/$CNAME/UBOOT.USB" "$TMP"
    PACKER="./tools/aml_image_v2_packer_new"
fi

$PACKER -r "$TMP/image.cfg" "$TMP" output/$OUTIMG

if [[ "$COMPRESS" == "yes" ]]; then
    cd output
    zip "$OUTIMG.zip" "$OUTIMG"
    cd ..
    rm "output/$OUTIMG"
    #xz --threads=0 "output/$OUTIMG"
fi

rm -rf $TMP
