#!/bin/bash

######################################################################
#
#  Copyright (c) 2017 revosftw (https://github.com/revosftw)
#
######################################################################

nano /etc/locale.gen;locale-gen;echo LANG=en_US.UTF-8 > /etc/locale.conf;
export LANG=en_US.UTF-8 ln -s /usr/share/zoneinfo/Australia/Adelaide /etc/localtime;
hwclock --systohc --utc
rm /etc/hostname echo "jok3r" | tee -a /etc/hostname
echo "Root password";
passwd useradd -m -g users -G wheel,storage,power -s /bin/bash YOURUSERNAMEHERE;
passwd YOURUSERNAMEHERE 
cd ~/ wget https://aur.archlinux.org/packages/ya/yaourt/yaourt.tar.gz;
wget https://aur.archlinux.org/packages/pa/package-query/package-query.tar.gz
nano /etc/sudoers
xdg-user-dirs-update
grub-install --recheck /dev/sda;
grub-mkconfig -o /boot/grub/grub.cfg
