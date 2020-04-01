#!/bin/bash

################################################################################
#
#  Copyright (c) 2019 revosftw (https://github.com/revosftw)
#
################################################################################

# GLOBAL VARIABLES {{{
  checklist=( 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
  # COLORS
    Bold=$(tput bold)
    Underline=$(tput sgr 0 1)
    Reset=$(tput sgr0)
    # Regular Colors
    Red=$(tput setaf 1)
    Green=$(tput setaf 2)
    Yellow=$(tput setaf 3)
    Blue=$(tput setaf 4)
    Purple=$(tput setaf 5)
    Cyan=$(tput setaf 6)
    White=$(tput setaf 7)
    # Bold
    BRed=${Bold}${Red}
    BGreen=${Bold}${Green}
    BYellow=${Bold}${Yellow}
    BBlue=${Bold}${Blue}
    BPurple=${Bold}${Purple}
    BCyan=${Bold}${Cyan}
    BWhite=${Bold}${White}

  # PROMPT
    prompt1="Enter your option: "
    prompt2="Enter n° of options (ex: 1 2 3 or 1-3): "
    prompt3="You have to manually enter the following commands, then press ${BYellow}ctrl+d${Reset} or type ${BYellow}exit${Reset}:"

  # EDITOR
    AUTOMATIC_MODE=0
    if [[ -f /usr/bin/vim ]]; then
      EDITOR="vim"
    elif [[ -z $EDITOR ]]; then
      EDITOR="nano"
    fi

  # MOUNTPOINTS
    EFI_MOUNTPOINT=""
    ROOT_MOUNTPOINT=""
    BOOT_MOUNTPOINT=""
    MOUNTPOINT=""

  # PARTITIONS
    ROOT_PARTITION=""
    BOOT_PARTITION=""
    HOME_PARTITION=""
    VAR_PARTITION=""

  ARCHI=`uname -m` # ARCHITECTURE
  UEFI=0
  LVM=0
  LUKS=0
  LUKS_DISK=""
  AUR=`echo -e "(${BPurple}aur${Reset})"`
  EXTERNAL=`echo -e "(${BYellow}external${Reset})"`
  AUI_DIR=`pwd` #CURRENT DIRECTORY
  [[ $1 == -v || $1 == --verbose ]] && VERBOSE_MODE=1 || VERBOSE_MODE=0 # VERBOSE MODE
  LOG="${AUI_DIR}/`basename ${0}`.log" # LOG FILE
  [[ -f $LOG ]] && rm -f $LOG
  PKG=""
  PKG_FAIL="${AUI_DIR}/`basename ${0}`_fail_install.log"
  [[ -f $PKG_FAIL ]] && rm -f $PKG_FAIL
  XPINGS=0 # CONNECTION CHECK
  SPIN="/-\|" #SPINNER POSITION
  AUTOMATIC_MODE=0
  TRIM=0
#}}}
  OPTION=""
###############################
### FUNCTIONS ###
###############################

# COMMON FUNCTIONS {{{
  # PRINT MESSAGES
    error_msg() {
      local _msg="${1}"
      echo -e "${_msg}"
      exit 1
    }

    cecho() {
      echo -e "$1"
      echo -e "$1" >>"$LOG"
      tput sgr0;
    }

    ncecho() {
      echo -ne "$1"
      echo -ne "$1" >>"$LOG"
      tput sgr0
    }

    spinny() {
      echo -ne "\b${SPIN:i++%${#SPIN}:1}"
    }

    progress() {
      ncecho "  ";
      while true; do
        kill -0 $pid &> /dev/null;
        if [[ $? == 0 ]]; then
          spinny
          sleep 0.25
        else
          ncecho "\b\b";
          wait $pid
          retcode=$?
          echo -ne "$pid's retcode: $retcode" >> $LOG
          if [[ $retcode == 0 ]] || [[ $retcode == 255 ]]; then
            cecho success
          else
            cecho failed
            echo -e "$PKG" >> $PKG_FAIL
            tail -n 15 $LOG
          fi
          break
        fi
      done
    }

  # INPUT/OUTPUT
    read_input() {
      if [[ $AUTOMATIC_MODE -eq 1 ]]; then
        OPTION=$1
      else
        read -p "$prompt1" OPTION
      fi
    }

    read_input_text() {
      if [[ $AUTOMATIC_MODE -eq 1 ]]; then
        OPTION=$2
      else
        read -p "$1 [y/N]: " OPTION
        echo ""
      fi
      OPTION=`echo "$OPTION" | tr '[:upper:]' '[:lower:]'`
    }

    read_input_options() {
      local line
      local packages
      if [[ $AUTOMATIC_MODE -eq 1 ]]; then
        array=("$1")
      else
        read -p "$prompt2" OPTION
        array=("$OPTION")
      fi
      for line in ${array[@]/,/ }; do
        if [[ ${line/-/} != $line ]]; then
          for ((i=${line%-*}; i<=${line#*-}; i++)); do
            packages+=($i);
          done
        else
          packages+=($line)
        fi
      done
      OPTIONS=("${packages[@]}")
    }

    print_line() {
      printf "%$(tput cols)s\n"|tr ' ' '-'
    }

    print_title() {
      clear
      print_line
      echo -e "# ${Bold}$1${Reset}"
      print_line
      echo ""
    }

    print_info() {
      #Console width number
      T_COLS=`tput cols`
      echo -e "${Bold}$1${Reset}\n" | fold -sw $(( $T_COLS - 18 )) | sed 's/^/\t/'
    }

    print_warning() {
      T_COLS=`tput cols`
      echo -e "${BYellow}$1${Reset}\n" | fold -sw $(( $T_COLS - 1 ))
    }

    print_danger() {
      T_COLS=`tput cols`
      echo -e "${BRed}$1${Reset}\n" | fold -sw $(( $T_COLS - 1 ))
    }

    invalid_option() {
      print_line
      echo "Invalid option. Try another one."
      pause_function
    }

    pause_function() {
      print_line
      if [[ $AUTOMATIC_MODE -eq 0 ]]; then
        read -e -sn 1 -p "Press enter to continue..."
      fi
    }

  # VALIDATION FUNCTIONS
    contains_element() {
      #check if an element exist in a string
      for e in "${@:2}"; do [[ $e == $1 ]] && break; done;
    }

    validate_selected_option() {
      read_input_text "Do you want to continue?"
      case $OPTION in
        y|Y|yes)
          ;;
        n|N|no)
          $1
        ;;
        *)
          invalid_option
          validate_selected_option $1
        ;;
      esac
    }

  # PACKAGE MANAGER
    is_package_installed() {
      #check if a package is already installed
      for PKG in $1; do
        pacman -Q $PKG &> /dev/null && return 0;
      done
      return 1
    }

    package_install() {
      #install packages using pacman
      if [[ $AUTOMATIC_MODE -eq 1 || $VERBOSE_MODE -eq 0 ]]; then
        for PKG in ${1}; do
          local _pkg_repo=`pacman -Sp --print-format %r ${PKG} | uniq | sed '1!d'`
          case $_pkg_repo in
            "core")
              _pkg_repo="${BRed}${_pkg_repo}${Reset}"
              ;;
            "extra")
              _pkg_repo="${BYellow}${_pkg_repo}${Reset}"
              ;;
            "community")
              _pkg_repo="${BGreen}${_pkg_repo}${Reset}"
              ;;
            "multilib")
              _pkg_repo="${BCyan}${_pkg_repo}${Reset}"
              ;;
          esac
          if ! is_package_installed "${PKG}" ; then
            ncecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} Installing (${_pkg_repo}) ${Bold}${PKG}${Reset} "
            pacman -S --noconfirm --needed ${PKG} >>"$LOG" 2>&1 &
            pid=$!;progress $pid
          else
            cecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} Installing (${_pkg_repo}) ${Bold}${PKG}${Reset} exists "
          fi
        done
      else
        pacman -S --needed ${1}
      fi
    }

    aui_download_packages() {
      for PKG in $1; do
        #exec command as user instead of root
        su - ${username} -c "
          [[ ! -d aui_packages ]] && mkdir aui_packages
          cd aui_packages
          curl -o ${PKG}.tar.gz https://aur.archlinux.org/cgit/aur.git/snapshot/${PKG}.tar.gz
          tar zxvf ${PKG}.tar.gz
          rm ${PKG}.tar.gz
          cd ${PKG}
          makepkg -csi --noconfirm
        "
      done
    }

    aur_package_install() {
      su - ${username} -c "sudo -v"
      #install package from aur
      for PKG in $1; do
        if ! is_package_installed "${PKG}" ; then
          if [[ $AUTOMATIC_MODE -eq 1 ]]; then
            ncecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} Installing ${AUR} ${Bold}${PKG}${Reset} "
            su - ${username} -c "${AUR_PKG_MANAGER} --noconfirm -S ${PKG}" >>"$LOG" 2>&1 &
            pid=$!;progress $pid
          else
            su - ${username} -c "${AUR_PKG_MANAGER} --noconfirm -S ${PKG}"
          fi
        else
          if [[ $VERBOSE_MODE -eq 0 ]]; then
            cecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} Installing ${AUR} ${Bold}${PKG}${Reset} success"
          else
            echo -e "Warning: ${PKG} is up to date --skipping"
          fi
        fi
      done
    }

  # CONFIGURE SYSTEM
    config_xinitrc() {
      #create a xinitrc file in home user directory
      cp -fv /etc/X11/xinit/xinitrc /home/${username}/.xinitrc
      echo -e "exec $1" >> /home/${username}/.xinitrc
      chown -R ${username}:users /home/${username}/.xinitrc
    }

    setlocale() {
      local _locale_list=(`cat /etc/locale.gen | grep UTF-8 | sed 's/\..*$//' | sed '/@/d' | awk '{print $1}' | uniq | sed 's/#//g'`);
      PS3="$prompt1"
      echo "Select locale:"
      select LOCALE in "${_locale_list[@]}"; do
        if contains_element "$LOCALE" "${_locale_list[@]}"; then
          LOCALE_UTF8="${LOCALE}.UTF-8"
          break
        else
          invalid_option
        fi
      done
    }

    settimezone() {
      local _zones=(`timedatectl list-timezones | sed 's/\/.*$//' | uniq`)
      PS3="$prompt1"
      echo "Select zone:"
      select ZONE in "${_zones[@]}"; do
        if contains_element "$ZONE" "${_zones[@]}"; then
          local _subzones=(`timedatectl list-timezones | grep ${ZONE} | sed 's/^.*\///'`)
          PS3="$prompt1"
          echo "Select subzone:"
          select SUBZONE in "${_subzones[@]}"; do
            if contains_element "$SUBZONE" "${_subzones[@]}"; then
              break
            else
              invalid_option
            fi
          done
          break
        else
          invalid_option
        fi
      done
    }

    npm_install() {
      #install packages using pacman
      npm install -g $1
    }

    gem_install() {
      #install packages using pacman
      for PKG in ${1}; do
        sudo -u ${username} gem install -V $PKG
      done
    }

#}}}

# INSTALLATION FUNCTIONS {{{
  select_partition() {
    local _partition_list=(`lsblk --list --output NAME --noheadings`)
    PS3="$prompt1"
    ncecho "Select a partition to use as root (ex: sda1): "
    select _PARTITION in "${_partition_list[@]}"; do
      if contains_element "$_PARTITION" "${_partition_list[@]}"; then
        PARTITION="/dev/${_PARTITION}"
        validate_selected_option select_partitions
        break
      else
        invalid_option
      fi
    done
    echo "${PARTITION}"
  }

  select_partitions() {
    # Select ROOT Partition
    ncecho "Select ROOT Partition"
    ROOT_PARTITION=$(select_partitions)
    ncecho "ROOT_PARTITION: ${ROOT_PARTITION}"

    # Select HOME Partition
    ncecho "Select HOME Partition"
    HOME_PARTITION=$(select_partitions)
    ncecho "HOME_PARTITION: ${HOME_PARTITION}"

    # Select VAR Partition
    ncecho "Select VAR Partition"
    VAR_PARTITION=$(select_partitions)
    ncecho "VAR_PARTITION: ${VAR_PARTITION}"

    # Select BOOT Partition
    ncecho "Select BOOT Partition"
    BOOT_PARTITION=$(select_partitions)
    ncecho "BOOT_PARTITION: ${BOOT_PARTITION}"
  }

  format_partitions() {

  }
#}}}

###############################
### DRIVER FUNCTION ###
###############################
function main() {
  local _options=("select_partitions" "format_partitions" "install_base" "install_desktop" "install_aur" "install_bootloader" "quit")
  print_line
  print_title "Install ArchLinux Menu"
  _option=$(read_input_options _options)
  echo _options
}

while :
  do
    main
  done

echo -en "\nCreate new ext4 filesystem on: $part? [y/n]: "
read input

case "$input" in
	y|Y|yes)	mkfs.ext4 /dev/$part
	;;
	n|N|no) echo -e "\nContinuing without creating filesystem."
	;;
	*)	echo -e "\nError: invalid option. Exiting."
		exit 1
	;;
esac

echo -e "\nMounting $part at mountpoint /mnt"
mount /dev/$part /mnt

if [ "$?" -gt "0" ]; then
	echo -e "\nFailed to mount $part. Exiting..."
	exit 1
fi

echo -e "\nBegining Arch Linux install to /dev/$part\n"
pacstrap /mnt base base-devel dialog wpa_supplicant bash-completion wget dkms net-tools grub os-prober

if [ "$?" -gt "0" ]; then
	echo -e "\nInstall failed. Exiting..."
	exit 1
fi

echo -e "\nGenerating fstab..."
genfstab -U -p /mnt >> /mnt/etc/fstab

grub_part=$(echo "$part" | grep -o "sd.")
echo -e "\nInstalling grub..."
arch-chroot /mnt grub-install --recheck /dev/$grub_part
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\nSet and generate locale"
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

echo -e "\nSet timezone"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
arch-chroot /mnt hwclock --systohc --utc

echo -en "\nEnter your desired hostname: "
read hostname
echo "$hostname" > /mnt/etc/hostname

while (true) ; do
	echo -en "\nEnter a new root password: "
	read -s password
	echo
	echo -en "Confirm root password: "
	read -s password_confirm

	if [ "$password" != "$password_confirm" ]; then
		echo -e "\nError: passwords do not match. Try again..."
	else
		printf "$password\n$password_confirm" | arch-chroot /mnt passwd &>/dev/null
		unset password password_confirm
		break
	fi
done

echo
echo -en "Enter a new username: "
read username
arch-chroot /mnt useradd -m -g users -G wheel,power,audio,video,storage -s /bin/bash "$username"

while (true) ; do
	echo -en "\nEnter a new password for $username: "
	read -s password
	echo
	echo -en "Confirm $username password: "
	read -s password_confirm

	if [ "$password" != "$password_confirm" ]; then
		echo -e "\nError: passwords do not match. Try again..."
	else
		printf "$password\n$password_confirm" | arch-chroot /mnt passwd "$username" &>/dev/null
		unset password password_confirm
		break
	fi
done

echo -e "\nEnabling sudo for $username..."
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers

echo -e "\nEnabling dhcp..."
arch-chroot /mnt systemctl enable dhcpcd

echo -e "\nInstall complete. Unmount system"
umount -R /mnt

