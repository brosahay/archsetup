#!/bin/bash

######################################################################
#
#  Copyright (c) 2017 revosftw (https://github.com/revosftw)
#
######################################################################

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
curl -L "https://www.archlinux.org/mirrorlist/all/" --output /tmp/mirrorlist.new
mv /tmp/mirrorlist.new /etc/pacman.d/mirrorlist
reflector --verbose -l 50 --sort rate --save /etc/pacman.d/mirrorlist