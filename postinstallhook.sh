setupdir=$1
username=$2
password=$3
grubconfirm=$4
removable=$5
efidevice=$6
source /$setupdir/pkgs.sh || exit 1

printf "\n\n# Changing system settings #\n\n"
sleep 2
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
locale-gen
sed -i -e's|#ParallelDownloads = 5|ParallelDownloads = 8|g' /etc/pacman.conf
sed -i -e's/# %wheel ALL=(ALL:ALL) NOPASSWD/%wheel ALL=(ALL:ALL) NOPASSWD/g' /etc/sudoers
pacman -Sy --noconfirm archlinux-keyring

printf "\n\n# Enabling services #\n\n"
sleep 2
systemctl enable $services

printf "\n\n# Making user $username #\n\n"
sleep 2
useradd -m -G wheel $username
echo "root:$password" | chpasswd
echo "$username:$password" | chpasswd

! test /bin/sudo && exit 1

printf "\n\n# Setting up config for $username #\n\n"
sleep 2
sudo -u $username -H bash -c "
mkdir -p /home/$username/Repos /home/$username/Downloads
tar --overwrite -xzf /$setupdir/themes.tar.gz -C /home/$username/
cd /home/$username/Repos
git clone https://github.com/oranellis/dotfiles
/home/$username/Repos/dotfiles/link.sh
"

if [[ $grubconfirm =~ ^[Yy]$ ]]; then
	if [ -n "$efidevice" ]; then
		printf "\n\n# Installing bootloader to device: $efidevice #\n\n"
		sleep 2
		mkdir -p /boot/efi
		mount $efidevice /boot/efi || exit 1

		if [[ $removable =~ ^[Yy]$ ]]; then
			bash -c "grub-install --removable --boot-directory=/boot --efi-directory=/boot/efi --themes=starlight"
		else
			bash -c "grub-install --bootloader-id=\"ArchLinux\" --boot-directory=/boot --efi-directory=/boot/efi --themes=starlight"
		fi

		sed -i'' -e'/GRUB_TIMEOUT=.*/d' -e'/GRUB_DISTRIBUTOR=.*/d' -e'/GRUB_CMDLINE_LINUX_DEFAULT=.*/d' -e'/GRUB_TIMEOUT_STYLE=.*/d' /etc/default/grub
		printf "GRUB_TIMEOUT=0\nGRUB_DISTRIBUTOR=\"ArchLinux\"\nGRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"\nGRUB_TIMEOUT_STYLE=hidden" >> /etc/default/grub
		grub-mkconfig -o /boot/grub/grub.cfg

		umount $efidevice
	else
		printf "\n\nError, no EFI partition found\n\n"
		sleep 2
	fi
fi

echo "
#####################
# Installation done #
#####################"
