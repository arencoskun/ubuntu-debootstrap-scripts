#!/bin/bash

DEBOOTSTRAP=y

if [ "$1" = "n" ]; then
    DEBOOTSTRAP=n
fi

echo "Will run debootstrap? : $DEBOOTSTRAP"
echo "If you do not want to run debootstrap, then run the command with the argument \"n\""
echo "If you choose to not run debootstrap, make sure your debootstrap directory is named **chroot**."

echo "Do you want to continue? (y/n)"
read -r response


if [ "$response" = "n" ]; then
    echo "Exiting..."
    exit 0
fi


echo "Running debootstrap for Ubuntu 22.04 Noble Numbat..."
echo "You will need to enter your password to run debootstrap."

sudo debootstrap --arch=amd64 noble chroot http://archive.ubuntu.com/ubuntu

echo "Mounting /proc to chroot..."
sudo mount --bind /proc chroot/proc/
echo "Mounting /sys to chroot..."
sudo mount --bind /sys chroot/sys/
echo "Mounting /dev to chroot..."
sudo mount --bind /dev chroot/dev/

echo "You are now ready to enter chroot."
