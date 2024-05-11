#!/bin/bash

printf "
####################
# System installer #
####################\n\n"

if [ $UID -ne 0 ]; then
	printf "Script must be run as root\n\n"
	exit 1
fi
if [ -n "$SUDO_COMMAND" ]; then
	printf "Script must be run as root and not with sudo\n\n"
	exit 1
fi

echo 'Enter Username: '
read username
echo 'Enter password: '
read -s password
echo ; read -p 'Perform auto grub install? ' -n 1 -r grubconfirm
if [[ $grubconfirm =~ ^[Yy]$ ]]; then
echo ; read -p 'Setup device as removable? ' -n 1 -r removable
else
removable="n"
fi
printf "\n\n\n"

dir=$(pwd)
scriptdir=$(dirname $0)
scriptdirname=$(basename $scriptdir)
source $scriptdir/pkgs.sh || exit 1
if [[ $grubconfirm =~ ^[Yy]$ ]]; then
	rootdev=$(echo $(findmnt --output source --noheadings -T $dir ) | sed "s/[p]\?[1-9]$//")
	efidevice=$(lsblk -o PATH,PARTTYPE $rootdev | sed -n 's/[ ]*c12a7328-f81f-11d2-ba4b-00a0c93ec93b//p')
fi

sed -i -e's|#ParallelDownloads = 5|ParallelDownloads = 8|g' /etc/pacman.conf
pacman -Sy --noconfirm archlinux-keyring || exit 1
pacstrap $dir $pkgs || exit 1
genfstab -U $dir >> $dir/etc/fstab
echo 'oComputer' >> $dir/etc/hostname
sed -i -e's/#en_US.UTF-8/en_US.UTF-8/g' $dir/etc/locale.gen
sed -i -e's/#en_GB.UTF-8/en_GB.UTF-8/g' $dir/etc/locale.gen
mkdir -p $dir/usr/local/bin
cp $scriptdir/scripts/* $dir/usr/local/bin/
cp -r "$scriptdir" "$dir"

printf "\n\nChrooting into target device...\n\n"
arch-chroot $dir /bin/bash /$scriptdirname/postinstallhook.sh $scriptdirname $username $password $grubconfirm $removable $efidevice
