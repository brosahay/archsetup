#!/bin/bash

######################################################################
#
#  Copyright (c) 2017 revosftw (https://github.com/revosftw)
#
######################################################################

echo -e "Installing Gnome Minimal"
pacman -S xorg-server xorg-server-utils xorg-xinit xorg-xrandr xorg-drivers
pacman -S file-roller gedit  gnome-calculator gnome-control-center gnome-screenshot gnome-system-monitor gnome-terminal gnome-tweak-tool mutter nautilus noise-player vala viewnior vlc 
pacman -S baobab evince gdm gnome-backgrounds gnome-session gnome-shell-extensions gnome-themes-standard gvfs-mtp gvfs-nfs gvfs-smb xdg-user-dirs