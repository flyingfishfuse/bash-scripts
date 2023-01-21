#!/bin/bash

show_help(){
cat <<EOF 
 $PROG Live_USB_creator.sh 
 This program makes a live USB with persistance utilizing syslinux
 CURRENTLY ONLY 64-BIT BOOTLOADER IS WORKING
 Usage: $PROG [OPTION...] [COMMAND]...
 Options:
  -a, --architecture ARCH   AMD64, X86, ARM,                           ( Required, Default: amd64 )

  -l, --live_iso ISO_PATH   full system path to live iso file
                            e.g. (/home/USER/Downloads/debian.iso)     ( Required, Default: NONE )

  -d, --device DEVICE       The device to install the Distro to        ( Required, Default: NONE )

  -g, --get_new_iso         Downloads Debian iso from official sources ( Default: NONE )
                            saves to /home/USER/Downloads/debian.iso
                            use this function alone, then run the 
                            program again with the expected args for
                            creation of a live USB

 Commands:
  -h, --help Displays this help and exits

   Thanks:
    That one person on stackexchange who answered everything in one post.
    The internet and search engines!

 how-can-i-pass-a-command-line-argument-into-a-shell-script
 https://unix.stackexchange.com/questions/31414/

 uefi-bios-bootable-live-debian-stretch-amd64-with-persistence
 https://unix.stackexchange.com/questions/382817/

EOF
}
read -r -d '' empty_required_args_error_message<<'EOF'
###############################################################################
[-]
[-] ERROR: Some or all of the required parameters are empty.
[-] You must provide the following:
[-]
[-]     Desired processor architecture for the bootloader
[-]         example: amd64
[-]
[-]     Full system path to a debian live iso
[-]         example: /home/user/Downloads/debian.iso
[-]
[-]     Device path of unpartitioned device
[-]         example: /dev/sdb
[-]
###############################################################################
EOF

#-v, --version  Displays output version and exits
#print_version_information(){}

PROG=${0##*/}
LOGFILE="$0.logfile"
die() { echo $@ >&2; exit 2; }


green="$(tput setaf 2)"
red=$(tput setaf 1)
yellow=$(tput setaf 3)

# prints color strings to terminal
# Argument $1 = message
# Argument $2 = color
cecho ()
{
  local default_msg="No message passed."
  # Doesn't really need to be a local variable.
  # Message is first argument OR default
  # color is second argument
  message=${1:-$default_msg}   # Defaults to default message.
  color=${2:-$black}           # Defaults to black, if not specified.
  printf "%b \n" "${color}${message}"
  #printf "%b \n" "${color}${message}"
  tput sgr0 #Reset # Reset to normal.
}

error_exit()
{
echo "$1" red 1>&2 >> "$LOGFILE"
exit 1
}

architecture()
{
    if $1; then
        architecture=$1
    else
        echo "[-] architecture not supplied as argument, cannot proceed"
    fi
}
source_live_iso="/home/$USER/Downloads/debian.iso"

# param1 : device id in the form of /dev/sda without the /dev/
set_target_device()
{
device="$1"
echo " Device chosen is /dev/$device"
}

# downloads a new iso for packing
get_new_iso()
{
wget -O "/home/$USER/Downloads/debian.iso" \
https://cdimage.debian.org/images/unofficial/non-free/images-including-firmware/11.6.0-live+nonfree/amd64/iso-hybrid/debian-live-11.6.0-amd64-cinnamon+nonfree.iso
}

#set_source_live_iso()
# {
#source_live_iso=live.iso
#}
#temp_efi_dir="/tmp/usb-efi"
#temp_live_dir="/tmp/usb-live"
#temp_persist_dir="/tmp/usb-persistence"
#temp_live_iso_dir="/tmp/live-iso"
set_temp_dirs()
{
temp_efi_dir=/tmp/usb-efi
temp_live_dir=/tmp/usb-live
temp_persist_dir=/tmp/usb-persistence
temp_live_iso_dir=/tmp/live-iso
}
#--------------------------------------
# Checks if partition has been mounted
# or created
# param1: device (/dev/sdxx)
check_partitions()
{
#   -d, --dry-run    do not actually inform the operating system
#   -s, --summary    print a summary of contents

#On a disk with no partition table:
# partprobe -d -s /dev/sdb
#(no output)

#On a disk with a partition table but no partitions:
# partprobe -d -s /dev/sdb
#/dev/sdb: msdos partitions

#On a disk with a partition table and one partition:
# partprobe -d -s /dev/sdb
#/dev/sdb: msdos partitions 1

#On a disk with a partition table and multiple partitions:
# partprobe -d -s /dev/sda
#/dev/sda: msdos partitions 1 2 3 4 <5 6 7>

if partprobe -d -s "$1"; then
    #moop@devbox:~$ sudo partprobe -d -s /dev/sda ; echo $?
    #/dev/sda: msdos partitions 1 2
    #0
    cecho "[+] Found $1, skipping operation" "$green"
    return 0
else
    #moop@devbox:~$ sudo partprobe -d -s /dev/sda3 ; echo $?
    #Error: Could not stat device /dev/sda3 - No such file or directory.
    #1
    cecho "[-] " "$red"
    return 0
fi
#if grep -qs '/dev/sdc' /proc/mounts; then
#    cecho "[+] $1 " "$yellow"
#fi

}

setup_EFI()
{
# This creates the basic disk structure of an EFI disk with a single OS.
# You CAN boot .ISO Files from the persistance partition if you mount in GRUB2

# EFI
# creates /dev/xx1
# check for flag before attempting operation
cecho "[+] checking if EFI partition has already been created" "$green"
    #if partprobe -d -s /dev/sdb1 print | grep "msftdata"; then
if sudo partprobe -d -s /dev/sdb print ; then
    if sudo partprobe -d -s "$device"1; then
        cecho "[+] Found /dev/{$device}1, skipping operation" "$green"
    else
        cecho "[+] creating EFI partition" "$green"
        if sudo parted "$device" --script mkpart EFI fat16 1MiB 100MiB &>> "$LOGFILE"; then
            cecho "[+] EFI partition created" "$green"
        else
            cecho "[+] Could not create EFI partition, check the logfile" "$red"
            exit
        fi
    fi
fi
}
setup_LIVE()
{
# LIVE disk partition   
# creates /dev/xx2
cecho "[+]  checking if LIVE partition has already been created" "$green"
if partprobe -d -s "$device"2; then
    cecho "[+] Found /dev/{$device}2, skipping operation" "$green"
else
    if parted "$device" --script mkpart live fat16 100MiB 3GiB &>> "$LOGFILE"; then
    cecho "[+] LIVE partition created " "$green"
    else
        cecho "[+] Could not create live partition, check the logfile" "$red"
        exit
    fi
fi
}

# Persistance Partition
# creates /dev/xx3
setup_persistance()
{
cecho "[+]  checking if PERSISTANCE partition has already been created" "$green"
if partprobe -d -s "$device"3; then
    cecho "[+] Found /dev/{$device}3, skipping operation" "$green"
else
    if parted "$device" --script mkpart persistence ext4 3GiB 100% &>> "$LOGFILE" ; then
        cecho "[+] Persistance partition created " "$green"
    else
        cecho "[+] Could not create Persistance partition, check the logfile" "$red"
        exit
    fi
fi
}
set_flags()
{
# Sets filesystem flag
cecho "[+] setting msftdata flag" "$green"
if parted "$device" --script set 1 msftdata on &>> "$LOGFILE"; then
    cecho "[+] Flag set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
    exit
fi

# Sets boot flag for legacy (NON-EFI) BIOS
cecho "[+] Setting boot flag for legacy (NON-EFI) BIOS" "$green"
if parted "$device" --script set 2 legacy_boot on &>> "$LOGFILE"; then
    cecho "[+] boot flag set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
fi

# Sets msftdata flag
cecho "[+] Setting msftdata flag" "$green"
if parted "$device" --script set 2 msftdata on &>> "$LOGFILE"; then
    cecho "[+] Flag Set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
fi
}

create_LIVE_VFAT_file_systems()
{
# Here we make the filesystems for the OS to live on
# EFI
cecho "[+] creating vfat on EFI partition" "$green"
if mkfs.vfat -n EFI "/dev/$device"1 &>> "$LOGFILE"; then
    cecho "[+] vfat filesystem created on EFI partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}
# LIVE disk partition
create_LIVE_filesystem()
{
cecho "[+] creating vfat on LIVE partition" "$green"
if mkfs.vfat -n LIVE "/dev/$device"2 &>> "$LOGFILE"; then
    cecho "[+] vfat filesystem created on LIVE partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}
create_persistant_filesystem()
{
# Persistance Partition
cecho "[+] creating ext4 on persistance partition" "$green"
if mkfs.ext4 -F -L persistence "/dev/$device"3 &>> "$LOGFILE"; then
    cecho "[+] Ext4 filesystem created on persistance partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}

# Creating Temporary work directories
create_temp_work_dirs()
{
cecho "[+] creating temporary work directories " "$green"
if mkdir $temp_efi_dir $temp_live_dir $temp_persist_dir $temp_live_iso_dir &>> "$LOGFILE"; then
    cecho "[+] Temporary work directories created" "$green"
else
    cecho "[+] ERROR: Failed to create temporary work directories, check the logfile" "$red"
    exit
fi
}

# Mounting those directories on the newly created filesystem
mount_EFI()
{
cecho "[+] mounting EFI partition on temporary work directory" "$green"
if mount "$device"1 /tmp/usb-efi &>> "$LOGFILE";then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+]  ERROR: Failed to mount partition, check the logfile" "$red"
    exit
fi
}

mount_LIVE()
{
cecho "[+] mounting LIVE partition on temporary work directory" "$green"
if mount "$device"2 /tmp/usb-live &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition , check the logfile" "$red"
    exit
fi
}

mount_PERSIST()
{
cecho "[+]  mounting persistance partition on temporary work directory" "$green"
if mount "$device"3 /tmp/usb-persistence &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition, check the logfile" "$red"
fi
}

mount_ISO()
{
# Mount the ISO on a temp folder to get the files moved
cecho "[+]  " "$green"
if mount -oro $live_iso_path /tmp/live-iso &>> "$LOGFILE";then
    cecho "[+]  " "$green"
else
    cecho "[+] ERROR: Failed to mount live iso, check the logfile" "$red"
fi
}

copy_ISO_to_tmp()
{
# copy files from live iso to live partition
if cp -ar /tmp/live-iso/* /tmp/usb-live &>> "$LOGFILE";then
    cecho "[+] copied filed from live iso to work directory" "$green"
else
    cecho "[+] ERROR: Failed to copy live iso files, check the logfile" "$red"
fi
}

enable_persistance()
{
# IMPORTANT! This establishes persistance! UNION is a special mounting option 
# https://unix.stackexchange.com/questions/282393/union-mount-on-linux
cecho "[+] Adding Union mount line to conf " "$green"

if echo "/ union" | tee /tmp/usb-persistence/persistence.conf &>> "$LOGFILE"; then
    cecho "[+] Added union mounting to live USB for persistance " "$green"
else
    cecho "[+] ERROR: Failed to, check the logfile" "$red"
fi
}
# Install GRUB2
# https://en.wikipedia.org/wiki/GNU_GRUB
##|Script supported targets: arm64-efi, x86_64-efi, , i386-efi
# TODO : Install 32bit brub2 then 64bit brub2 then `update-grub`
#So's we can install 32 bit OS to live disk.
#########################
##| 64-BIT OS   #
#########################
install_grub_to_image()
{
# if using ARM devices
if [ "$architecture" == "ARM" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to /dev/${device}" "$yellow"
    grub-install --removable --target=arm-efi --boot-directory=/tmp/usb-live/boot/ --efi-directory=/tmp/usb-efi "/dev/$device"
    if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" $green
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" 1>&2 >> "$LOGFILE"
    fi
fi
 
# if using x86
if [ "$architecture" == "X86" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to /dev/${device}" $yellow
    grub-install --removable --target=i386-efi --boot-directory=/tmp/usb-live/boot/ --efi-directory=/tmp/usb-efi "/dev/$device"
    if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" $green
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" 1>&2 >> "$LOGFILE"
    fi
fi

if [ "$architecture" == "X64" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to /dev/${device}" $yellow
    grub-install --removable --target=X86_64-efi --boot-directory=/tmp/usb-live/boot/ --efi-directory=/tmp/usb-efi "/dev/$device"
    if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" lolcat
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" 1>&2 >> "$LOGFILE"
    fi
fi
}

# Copy the MBR for syslinux booting of LIVE disk
# this is to the device itself, not any specific partition
copy_syslinux_to_MBR()
{
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/gptmbr.bin of="/dev/$device"
}

# Install Syslinux
# https://wiki.syslinux.org/wiki/index.php?title=HowTos
install_syslinux()
{
echo "/dev/$device"2 | syslinux --install
mv /tmp/usb-live/isolinux /tmp/usb-live/syslinux
mv /tmp/usb-live/syslinux/isolinux.bin /tmp/usb-live/syslinux/syslinux.bin
mv /tmp/usb-live/syslinux/isolinux.cfg /tmp/usb-live/syslinux/syslinux.cfg
}

# Magic, sets up syslinux configuration and layouts 
setup_boot_config()
{
sed --in-place 's#isolinux/splash#syslinux/splash#' /tmp/usb-live/boot/grub/grub.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 persistence/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 keyboard-layouts=en locales=en_US/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg
sed --in-place 's#isolinux/splash#syslinux/splash#' /tmp/usb-live/boot/grub/grub.cfg
}

# Clean up!
clean()
{
umount /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
rmdir /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
}

while getopts "a:l:d:g:h:v:" opt
do
   case "$opt" in
      a ) architecture="$OPTARG" ;;
      l ) live_iso_path="$OPTARG" ;;
      d ) device="$OPTARG" ;;
      g ) get_iso ;; # ="$OPTARG" ;;
      h ) show_help ;;
      v ) print_version_information ;;
      ? ) show_help ;; # Print helpFunction in case parameter is non-existent
   esac
done

# these are REQUIRED params
# Print help in case parameters are empty
# -z means non-defined or empty
if [ -z "$architecture" ] || [ -z "$live_iso_path" ] || [ -z "$device" ]
then
   echo "$empty_required_args_error_message"
   #show_help
fi

if get_iso
then
    cecho "[+] Downloading new Debian ISO"
fi
