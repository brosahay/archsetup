#!/bin/bash
echo -e "Installing Gnome Minimal"
pacstrap /mnt       file-roller gedit  gnome-calculator gnome-control-center gnome-screenshot gnome-system-monitor gnome-terminal gnome-tweak-tool mutter nautilus noise-player vala viewnior vlc 
pacstrap /mnt baobab evince gdm gnome-backgrounds gnome-session gnome-shell-extensions gnome-themes-standard gvfs-mtp gvfs-nfs gvfs-smb xdg-user-dirs