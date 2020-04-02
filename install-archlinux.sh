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
    ROOT_MOUNTPOINT="/mnt"
    EFI_MOUNTPOINT="${ROOT_MOUNTPOINT}/boot/efi"
    BOOT_MOUNTPOINT="${ROOT_MOUNTPOINT}/boot"
    VAR_MOUNTPOINT="${ROOT_MOUNTPOINT}/var"

  # PARTITIONS
    ROOT_PARTITION=""
    BOOT_PARTITION=""
    VAR_PARTITION=""
    HOME_PARTITION=""

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
    pacman_key(){ 
      if [[ ! -d /etc/pacman.d/gnupg ]]; then
        print_title "PACMAN KEY - https://wiki.archlinux.org/index.php/pacman-key"
        print_info "Pacman uses GnuPG keys in a web of trust model to determine if packages are authentic."
        package_install "haveged"
        haveged -w 1024
        pacman-key --init
        pacman-key --populate archlinux
        pkill haveged
        package_remove "haveged"
      fi
    }
    
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

    aur_package_install_git() {
      aur_url=$1
      cd /tmp
      git clone "${1}" aur_package_git
      cd aur_package_git
      makepkg -si
      cd ..
      rm -rf aur_package_git
    }

  # CONFIGURE SYSTEM
    arch_chroot() {
      arch-chroot $ROOT_MOUNTPOINT /bin/bash -c "${1}"
    }

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
      arch_chroot "echo ${LOCALE_UTF8} >> ${ROOT_MOUNTPOINT}/etc/locale.gen"
      arch_chroot "echo LANG=${LOCALE_UTF8} >> ${ROOT_MOUNTPOINT}/etc/locale.gen"
      arch_chroot locale-gen
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
      arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
      arch-chroot /mnt hwclock --systohc --utc
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

  format_partition() {
    local _PARTITION=${1}
    read_input_text "Create new ext4 filesystem on: ${_PARTITION}"
    case "${OPTION}" in
      y|Y|yes)
        mkfs.ext4 ${_PARTITION}
      ;;
      n|N|no)
       ncecho "\nContinuing without creating filesystem."
      ;;
      *)
      	invalid_option
        format_partition ${_PARTITION}
      ;;
    esac
  }

  mount_partitions() {
    if [[ "${ROOT_PARTITION}" != "" ]]; then
      print_info "Mounting ROOT_PARTITION (${ROOT_PARTITION}) to ${ROOT_MOUNTPOINT}."
      mount ${ROOT_PARTITION} ${ROOT_MOUNTPOINT}
    else
      print_warning "ROOT_PARTITION not selected"
      select_partitions
    fi

    if [[ "${BOOT_PARTITION}" != "" ]]; then
      print_info "Mounting BOOT_PARTITION (${BOOT_PARTITION}) to ${BOOT_MOUNTPOINT}."
      mount ${BOOT_PARTITION} ${BOOT_MOUNTPOINT}
    else
      print_warning "BOOT_PARTITION not selected"
      select_partitions
    fi

    if [[ "${VAR_PARTITION}" != "" ]]; then
      print_info "Mounting VAR_PARTITION (${VAR_PARTITION}) to ${VAR_MOUNTPOINT}."
      mount ${VAR_PARTITION} ${VAR_MOUNTPOINT}
    else
      print_warning "VAR_PARTITION not selected"
      select_partitions
    fi

    if [[ "${HOME_PARTITION}" != "" ]]; then
      print_info "Mounting HOME_PARTITION (${HOME_PARTITION}) to ${HOME_MOUNTPOINT}."
      mount ${HOME_PARTITION} ${HOME_MOUNTPOINT}
    else
      print_warning "HOME_PARTITION not selected"
      select_partitions
    fi
  }

  select_partitions() {
    cecho "Partition List:"
    lsblk --list
    # Select ROOT Partition
    cecho "Select ROOT Partition"
    ROOT_PARTITION=$(select_partition)
    cecho "ROOT_PARTITION: ${ROOT_PARTITION}"
    format_partition ${ROOT_PARTITION}

    read_input_text "Do you want seperate BOOT partition"
    if [[ $OPTION == y ]]; then
      # Select BOOT Partition
      cecho "Select BOOT Partition"
      BOOT_PARTITION=$(select_partition)
      cecho "BOOT_PARTITION: ${BOOT_PARTITION}"
      format_partition ${BOOT_PARTITION}
    fi
    
    read_input_text "Do you want seperate HOME partition"
    if [[ $OPTION == y ]]; then
      # Select HOME Partition
      cecho "Select HOME partition"
      HOME_PARTITION=$(select_partition)
      cecho "HOME_PARTITION: ${HOME_PARTITION}"
      format_partition ${HOME_PARTITION}
    fi

    read_input_text "Do you want seperate VAR partition"
    if [[ $OPTION == y ]]; then
      # Select VAR Partition
      cecho "Select VAR Partition"
      VAR_PARTITION=$(select_partition)
      cecho "VAR_PARTITION: ${VAR_PARTITION}"
      format_partition ${VAR_PARTITION}
    fi
  }

  generate_fstab() {
    print_info "Generating /etc/fstab"
    genfstab -U -p ${ROOT_MOUNTPOINT} >> "${ROOT_MOUNTPOINT}/etc/fstab"
  }

  set_hostname() {
    print_title "HOSTNAME"
    local _hostname
    ncecho "Enter your desired hostname: "
    read _hostname
    echo "$_hostname" > /mnt/etc/hostname
  }

  install_base() {
    if [[ "${ROOT_PARTITION}" != "" ]]; then
      print_title "BASE INSTALL - https://wiki.archlinux.org/index.php/Installation_guide"
      print_info "ArchLinux install base onto ${ROOT_MOUNTPOINT}"
      pacstrap ${ROOT_MOUNTPOINT} base linux linux-firmware base-devel dialog wpa_supplicant bash-completion wget dkms net-tools
      pause_function

      generate_fstab
      pause_function

      install_grub
      pause_function

      set_hostname
      pause_function
    else
      print_warning "No ROOT Partition selected"
    fi
  }

  install_grub() {
    print_title "GRUB - https://wiki.archlinux.org/index.php/GRUB"
    print_info "GRUB (GRand Unified Bootloader) is a multi-boot loader."
    package_install grub os-prober
    local _grub_install_location=$(echo ${ROOT_PARTITION} | grep -o "sd.")
    arch_chroot "grub-install --recheck /dev/$_grub_install_location"
    arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
    pause_function
  }

  change_root_passwd() {
    local password
    local password_confirm
    while (true) ; do
      echo -en "\nEnter a new root password: "
      read -s password
      echo
      echo -en "Confirm root password: "
      read -s password_confirm

      if [ "$password" != "$password_confirm" ]; then
        echo -e "\nError: passwords do not match. Try again..."
      else
        printf "$password\n$password_confirm" | arch_chroot "passwd & > /dev/null"
        unset password password_confirm
        break
      fi
    done
  }

  add_user_to_group() {
    local _user=${1}
    local _group=${2}

    if [[ -z ${_group} ]]; then
      error_msg "ERROR! 'add_user_to_group' was not given enough parameters."
    fi

    ncecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} Adding ${Bold}${_user}${Reset} to ${Bold}${_group}${Reset} "
    groupadd ${_group} >>"$LOG" 2>&1 &
    gpasswd -a ${_user} ${_group} >>"$LOG" 2>&1 &
    pid=$!;progress $pid
  }

  add_user() {
    local _username=${1}
    cecho "Enter a new username: "
    read _username
    arch_chroot "useradd -m -g users -G adm,wheel,power,audio,video,storage -s /bin/bash $username"
    add_user_to_sudo _username
  }

  add_user_to_sudo() {
    local _username=${1}
    echo -e "\nEnabling sudo for $_username..."
    sed -i '/%wheel ALL=(ALL) ALL/s/^#//' ${ROOT_MOUNTPOINT}/etc/sudoers
  }

   run_as_user() {
    sudo -H -u ${username} ${1}
  }

  system_ctl() {
    local _action=${1}
    local _object=${2}
    ncecho " ${BBlue}[${Reset}${Bold}X${BBlue}]${Reset} systemctl ${_action} ${_object} "
    systemctl ${_action} ${_object} >> "$LOG" 2>&1
    pid=$!;progress $pid
  }

  menu_item() { 
    #check if the number of arguments is less then 2
    [[ $# -lt 2 ]] && _package_name="$1" || _package_name="$2";
    #list of chars to remove from the package name
    local _chars=("Ttf-" "-bzr" "-hg" "-svn" "-git" "-stable" "-icon-theme" "Gnome-shell-theme-" "Gnome-shell-extension-");
    #remove chars from package name
    for char in ${_chars[@]}; do _package_name=`echo ${_package_name^} | sed 's/'$char'//'`; done
    #display checkbox and package name
    echo -e "$(checkbox_package "$1") ${Bold}${_package_name}${Reset}"
  }

  mainmenu_item() { 
    #if the task is done make sure we get the state
    if [ $1 == 1 -a "$3" != "" ]; then
      state="${BGreen}[${Reset}$3${BGreen}]${Reset}"
    fi
    echo -e "$(checkbox "$1") ${Bold}$2${Reset} ${state}"
  }

#}}}

###############################
### DRIVER FUNCTION ###
###############################

function echo_message(){
	local color=$1;
	local message=$2;
	if ! [[ $color =~ '^[0-9]$' ]] ; then
		case $(echo -e $color | tr '[:upper:]' '[:lower:]') in
			# black
			header) color=0 ;;
			# red
			error) color=1 ;;
			# green
			success) color=2 ;;
			# yellow
			welcome) color=3 ;;
			# blue
			title) color=4 ;;
			# purple
			info) color=5 ;;
			# cyan
			question) color=6 ;;
			# orange
			warning) color=202 ;;
			# white
			*) color=7 ;;
		esac
	fi
	tput bold;
	tput setaf $color;
	echo '-- '$message;
	tput sgr0;
}

# tab width
tabs 4
clear

# Title of script set
TITLE="ArchLinux Install Script"

# Main
function main {
	cecho "Starting 'main' function"
	# Draw window
	MAIN=$(eval `resize` && whiptail \
		--notags \
		--title "$TITLE" \
		--menu "\nWhat would you like to do?" \
		--cancel-button "Quit" \
		$LINES $COLUMNS $(( $LINES - 12 )) \
		'select_partitions'           'Select Partitions' \
		'mount_partitions'            'Mount Partitions' \
		'install_base'                'Install base system' \
		'install_desktop'             'Install desktop' \
		'install_aur'                 'Install AUR packages' \
		'install_bootloader'          'Install bootloader' \
		3>&1 1>&2 2>&3)
	# check exit status
	if [ $? = 0 ]; then
		cecho "Starting '$MAIN' function"
		$MAIN
	else
		# Quit
		quit
	fi
}

# Quit
function quit {
	cecho "Starting 'quit' function"
	cecho "Exiting $TITLE..."
	# Draw window
	if (whiptail --title "Quit" --yesno "Are you sure you want quit?" 8 56) then
		cecho 'Thanks for using!'
		exit 99
	else
		main
	fi
}

cecho "$TITLE"

while :
  do
    main
  done

echo -e "\nEnabling dhcp..."
arch-chroot /mnt systemctl enable dhcpcd

echo -e "\nInstall complete. Unmount system"
umount -R /mnt

