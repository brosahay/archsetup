#!/bin/bash

######################################################################
#
#  Copyright (c) 2017 revosftw (https://github.com/revosftw)
#
######################################################################

echo -en "Install Yaourt"
cd /tmp
wget https://aur.archlinux.org/packages/pa/package-query/package-query.tar.gz

wget https://aur.archlinux.org/packages/ya/yaourt/yaourt.tar.gz
tar zxvf yaourt.tar.gz
cd yaourt
makepkg -si

xdg-user-dirs-update