#!/bin/bash

DISTRONAME="Custom ISO"
VOLUMEID=CUSTOMISO
PWD=$(pwd)

read -r -d '' GRUBCFG_TEMPLATE << 'EOF'
search --set=root --file /$VOLUMEID

insmod all_video
set default="0"
set timeout=10

menuentry "$DISTRONAME Live" {
    linux /vmlinuz boot=live quiet nomodeset
    initrd /initrd
}
EOF

if [ $# -eq 0 ]; then
    echo "You are not setting a custom distro name or volume ID."
    echo "The distro name will be set as $DISTRONAME and the volume ID will be set as $VOLUMEID."
    echo "If this was not intentional, please run the program as:"
    echo "$0 <distroname> <volumeid>"
    echo "Do you want to continue? (y/n)"
    read -r response

    if [ "$response" = "n" ]; then
        echo "Exiting..."
        exit 0
    fi
else
    DISTRONAME="$1"
    VOLUMEID="$2"
fi

# Replace placeholders with actual variable values
GRUBCFG=$(echo "$GRUBCFG_TEMPLATE" | sed "s/\$DISTRONAME/$DISTRONAME/g; s/\$VOLUMEID/$VOLUMEID/g")

echo "Using distro name: $DISTRONAME and volume ID: $VOLUMEID"

echo "Unmounting chroot directories..."
sudo umount chroot/proc
sudo umount chroot/sys
sudo umount chroot/dev

echo "Creating required directories..."
mkdir -p scratch
mkdir -p image/live

echo "Creating filesystem.squashfs..."
sudo mksquashfs chroot image/live/filesystem.squashfs -e boot

echo "Copying vmlinuz file..."
sudo cp chroot/boot/vmlinuz-* image/vmlinuz
sudo cp chroot/boot/initrd.img-* image/initrd

echo "Creating grub.cfg..."
touch scratch/grub.cfg
echo "$GRUBCFG" > scratch/grub.cfg

touch "image/$VOLUMEID"

echo "Running grub-mkstandalone..."
grub-mkstandalone --format=x86_64-efi --output=scratch/bootx64.efi --locales="" --fonts="" "boot/grub/grub.cfg=$PWD/scratch/grub.cfg"

echo "Creating efiboot.img..."
cd scratch
dd if=/dev/zero of=efiboot.img bs=1M count=10
mkfs.vfat efiboot.img
mmd -i efiboot.img efi efi/boot
mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
cd ..

echo "Creating core.img..."
grub-mkstandalone --format=i386-pc --output="$PWD/scratch/core.img" --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" --modules="linux normal iso9660 biosdisk search" --locales="" --fonts="" "boot/grub/grub.cfg=$PWD/scratch/grub.cfg"

echo "Creating bios.img..."
cat /usr/lib/grub/i386-pc/cdboot.img "$PWD/scratch/core.img" > "$PWD/scratch/bios.img"

echo "Running xorriso to create ISO file..."
sudo xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "$VOLUMEID" \
    -eltorito-boot \
        boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
        -e EFI/efiboot.img \
        -no-emul-boot \
    -append_partition 2 0xef scratch/efiboot.img \
    -output "out.iso" \
    -graft-points \
        "$PWD/image" \
        /boot/grub/bios.img=scratch/bios.img \
        /EFI/efiboot.img=scratch/efiboot.img

