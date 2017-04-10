#!/bin/bash
pacstrap /mnt base base-devel xorg-server xorg-server-utils xorg-xinit xorg-xrandr xorg-drivers gdm gnome-themes-standard gnome-session gnome-shell-extensions dkms 
net-tools xdg-user-dirs sudo bash-completion wget grub os-prober baobab evince file-roller firefox gedit gnome-backgrounds gnome-calculator gnome-control-center 
gnome-screenshot gnome-system-monitor gnome-terminal gnome-tweak-tool gstreamer0.10-plugins mutter nautilus noise vala viewnior vlc
arch-chroot /mnt
