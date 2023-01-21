#!/bin/bash

PROG=${0##*/}
LOGFILE="$0.logfile"
#die() { echo $@ >&2; exit 2; }

show_help(){
cat <<EOF 
 $PROG Live_USB_creator.sh 
 This program makes a live USB with persistance utilizing syslinux
 CURRENTLY ONLY 64-BIT BOOTLOADER IS WORKING
 Usage: $PROG [OPTION...] [COMMAND]...
 Options:
  -a, --architecture ARCH   AMD64, X86, ARM,                           ( Required, Default: amd64 )

  -l, --iso_path ISO_PATH   full system path to live iso file
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

 using-getopts-to-process-long-and-short-command-line-options
 https://stackoverflow.com/questions/402377/

 uefi-bios-bootable-live-debian-stretch-amd64-with-persistence
 https://unix.stackexchange.com/questions/382817/

EOF
}
read -r -d '' empty_required_args_error_message<<'EOF'
###############################################################################
[-]
[-] ERROR: Some or all of the required parameters are empty.
[-]        You must provide the following:
[-]
[-]     Desired processor architecture for the bootloader
[-]
[-]         example: amd64
[-]
[-]     Full system path to a debian live iso, if you dont have one, you can 
[-]     run this program using the -g or --get_iso option to download one from
[-]     the official debian mirrors
[-]     
[-]         example: /home/user/Downloads/debian.iso
[-]
[-]     Device path of unpartitioned device
[-] 
[-]         example: /dev/sdb
[-]
###############################################################################
EOF

#-v, --version  Displays output version and exits
#print_version_information(){}

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

# downloads a new iso for packing
get_new_iso()
{
cecho "[+] Downloading new Debian ISO" "$green"
wget -O "/home/$USER/Downloads/debian.iso" https://cdimage.debian.org/images/unofficial/non-free/images-including-firmware/11.6.0-live+nonfree/amd64/iso-hybrid/debian-live-11.6.0-amd64-cinnamon+nonfree.iso
cecho "[+] Debian ISO has been downloaded to the following location: \n[+] /home/$USER/Downloads/debian.iso" "$green"
cecho "[+] Run this program again with the operational arguments to perform the creation of a live usb" "$green"
exit
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
temp_efi_dir="/tmp/usb-efi"
temp_live_dir="/tmp/usb-live"
temp_persist_dir="/tmp/usb-persistence"
temp_live_iso_dir="/tmp/live-iso"
}

# creates /dev/xx1 EFI boot partition
# This creates the basic disk structure of an EFI disk with a single OS.
create_EFI()
{

# check for flag before attempting operation
cecho "[+] checking if EFI partition has already been created" "$green"
    #if partprobe -d -s /dev/sdb1 print | grep "msftdata"; then
if sudo partprobe -d -s "$device"1; then
    cecho "[+] Found ${device}1, skipping operation" "$green"
else
    cecho "[+] creating EFI partition" "$green"
    if sudo parted "$device" --script mkpart EFI fat16 1MiB 100MiB &>> "$LOGFILE"; then
        cecho "[+] EFI partition created" "$green"
    else
        cecho "[+] Could not create EFI partition, check the logfile" "$red"
        exit
    fi
fi
}

# creates /dev/xxx2 LIVE disk partition
# you can chroot into the filesystem created by the usage of unsquashfs
# to modify the OS
create_LIVE()
{
cecho "[+]  checking if LIVE partition has already been created" "$green"
if sudo partprobe -d -s "$device"2; then
    cecho "[+] Found ${device}2, skipping operation" "$green"
else
    if sudo parted "$device" --script mkpart live fat16 100MiB 3GiB &>> "$LOGFILE"; then
    cecho "[+] LIVE partition created on $device " "$green"
    else
        cecho "[+] Could not create live partition, check the logfile" "$red"
        exit
    fi
fi
}

# creates /dev/xxx3 Persistance Partition
# You CAN boot .ISO Files from the persistance partition if you mount in GRUB2
create_PERSISTANT()
{
cecho "[+]  checking if PERSISTANCE partition has already been created" "$green"
if sudo partprobe -d -s "$device"3; then
    cecho "[+] Found ${device}3, skipping operation" "$green"
else
    if sudo parted "$device" --script mkpart persistence ext4 3GiB 100% &>> "$LOGFILE" ; then
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
if sudo parted "$device" --script set 1 msftdata on &>> "$LOGFILE"; then
    cecho "[+] Flag set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
    exit
fi

# Sets boot flag for legacy (NON-EFI) BIOS
cecho "[+] Setting boot flag for legacy (NON-EFI) BIOS" "$green"
if sudo parted "$device" --script set 2 legacy_boot on &>> "$LOGFILE"; then
    cecho "[+] boot flag set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
fi

# Sets msftdata flag
cecho "[+] Setting msftdata flag" "$green"
if sudo parted "$device" --script set 2 msftdata on &>> "$LOGFILE"; then
    cecho "[+] Flag Set" "$green"
else
    cecho "[+] Error setting flag, check the logfile" "$red"
fi
}

create_EFI_VFAT_file_systems()
{
# Here we make the filesystems for the OS to live on
# EFI
cecho "[+] creating vfat on EFI partition" "$green"
if sudo mkfs.vfat -n EFI "${device}"1 &>> "$LOGFILE"; then
    cecho "[+] vfat filesystem created on EFI partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}

# LIVE disk partition
create_LIVE_VFAT_filesystem()
{
cecho "[+] creating vfat on LIVE partition" "$green"
if sudo mkfs.vfat -n LIVE "${device}"2 &>> "$LOGFILE"; then
    cecho "[+] vfat filesystem created on LIVE partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}

create_persistant_filesystem()
{
# Persistance Partition
cecho "[+] creating ext4 on persistance partition" "$green"
if sudo mkfs.ext4 -F -L persistence "${device}"3 &>> "$LOGFILE"; then
    cecho "[+] Ext4 filesystem created on persistance partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}

# Creating Temporary work directories
create_temp_work_dirs()
{
cecho "[+] creating temporary work directories " "$green"
if sudo mkdir $temp_efi_dir $temp_live_dir $temp_persist_dir $temp_live_iso_dir &>> "$LOGFILE"; then
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
if sudo mount "$device"1 $temp_efi_dir &>> "$LOGFILE";then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+]  ERROR: Failed to mount partition, check the logfile" "$red"
    exit
fi
}

mount_LIVE()
{
cecho "[+] mounting LIVE partition on temporary work directory" "$green"
if sudo mount "$device"2 $temp_live_dir &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition , check the logfile" "$red"
    exit
fi
}

mount_PERSIST()
{
cecho "[+]  mounting persistance partition on temporary work directory" "$green"
if mount "$device"3 $temp_persist_dir &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition, check the logfile" "$red"
fi
}

mount_ISO()
{
# Mount the ISO on a temp folder to get the files moved
cecho "[+]  " "$green"
if sudo mount -oro "$iso_path" $temp_live_iso_dir &>> "$LOGFILE";then
    cecho "[+]  " "$green"
else
    cecho "[+] ERROR: Failed to mount live iso, check the logfile" "$red"
fi
}

copy_ISO_to_tmp()
{
# copy files from live iso to live partition
if sudo cp -ar $temp_live_iso_dir/* $temp_live_dir &>> "$LOGFILE";then
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

if echo "/ union" | sudo tee $temp_persist_dir/persistence.conf &>> "$LOGFILE"; then
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
#########################$temp_persist_dir

install_grub_to_image()
{
# if using ARM devices
if [ "$architecture" == "ARM" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to ${device}" "$yellow"
    if sudo grub-install --removable --target=arm-efi --boot-directory=$temp_live_dir/boot/ --efi-directory=$temp_efi_dir "${device}"
    then
    #if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" "$green"
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" &>> "$LOGFILE" #1>&2 >> "$LOGFILE"
    fi
fi
 
# if using x86
if [ "$architecture" == "X86" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to ${device}" "$yellow"
    if sudo grub-install --removable --target=i386-efi --boot-directory=$temp_live_dir/boot/ --efi-directory=$temp_efi_dir "${device}"
    then
    #if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" "$green"
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" &>> "$LOGFILE" #1>&2 >> "$LOGFILE"
    fi
fi

if [ "$architecture" == "x64" ]; then
    cecho "[+] Installing GRUB2 for ${architecture} to ${device}" "$yellow"
    if sudo grub-install --removable --target=X86_64-efi --boot-directory=$temp_live_dir/boot/ --efi-directory=$temp_efi_dir "${device}"
    then
    #if [ "$?" = "0" ]; then
        cecho "[+] GRUB2 Install Finished Successfully!" "$green"
    else
        error_exit "[-]GRUB2 Install Failed! Check the logfile!" &>> "$LOGFILE" #1>&2 >> "$LOGFILE"
    fi
fi
}

# Copy the MBR for syslinux booting of LIVE disk
# this is to the device itself, not any specific partition
copy_syslinux_to_MBR()
{
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/gptmbr.bin of="${device}"
}

# Install Syslinux
# https://wiki.syslinux.org/wiki/index.php?title=HowTos
install_syslinux()
{
echo "${device}"2 | syslinux --install
mv $temp_live_dir/isolinux $temp_live_dir/syslinux
mv $temp_live_dir/syslinux/isolinux.bin $temp_live_dir/syslinux/syslinux.bin
mv $temp_live_dir/syslinux/isolinux.cfg $temp_live_dir/syslinux/syslinux.cfg
}

# Magic, sets up syslinux configuration and layouts
setup_boot_config()
{
sed --in-place 's#isolinux/splash#syslinux/splash#' $temp_live_dir/boot/grub/grub.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 persistence/}' $temp_live_dir/boot/grub/grub.cfg $temp_live_dir/syslinux/menu.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 keyboard-layouts=en locales=en_US/}' $temp_live_dir/boot/grub/grub.cfg $temp_live_dir/syslinux/menu.cfg
sed --in-place 's#isolinux/splash#syslinux/splash#' $temp_live_dir/boot/grub/grub.cfg
}

# Clean up!
clean()
{
sudo umount $temp_efi_dir $temp_live_dir $temp_persist_dir $temp_live_iso_dir
sudo rmdir $temp_efi_dir $temp_live_dir $temp_persist_dir $temp_live_iso_dir
}

# put short options after -o without commas
# put long options after --long, with commas
# options that have no short option should have : after them, before the comma
TEMP_OPTS=$(getopt -o aldgh: --long architecture,iso_path,device,get_new_iso,help -n 'create_live_usb' -- "$@")

#if [ $? != 0 ] ; then 
#    echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP_OPTS"

while true; do
    case "$1" in
        --a | --architecture)   architecture="$2"; shift ;;
        --l | --iso_path)       iso_path="$2"; shift ;;
        --d | --device)         device="$2"; shift ;;
        --g | --get_new_iso)    get_new_iso ;;
        --h | --show_help )     show_help ;;
        --  )                   shift; break ;;
        *   )                   show_help; break ;;
    esac
done
#while getopts "a:l:d:g:h:v:" opt
#do
#   case "$opt" in
#      a | architecture) architecture="$OPTARG"; shift ;;
#      l ) live_iso_path="$OPTARG"; shift ;;
#      d ) device="$OPTARG"; shift ;;
#      g ) get_new_iso ;; # ="$OPTARG" ;;
#      h ) show_help ;;
#      ? ) show_help ;; # Print helpFunction in case parameter is non-existent
#   esac
#done

# these are REQUIRED params
# Print help in case parameters are empty
# -z means non-defined or empty
if [ -z "$architecture" ] || [ -z "$iso_path" ] || [ -z "$device" ]
then
   echo "$empty_required_args_error_message"
else
    # creates temporary work directories
    set_temp_dirs
    # creates efi partition
    create_EFI
    # creates live os partition
    create_LIVE
    # creates persistant data partition
    create_PERSISTANT

    # sets required flags on all partitions
    set_flags

    # create filesystems for EFI,live, and persistant partitions
    create_EFI_VFAT_file_systems
    create_LIVE_VFAT_filesystem
    create_persistant_filesystem

    # create temporary work directories for copying of files and mounting
    # of filesystems
    create_temp_work_dirs

    # mount the partitions on the temporary work directories
    mount_EFI
    mount_LIVE
    mount_PERSIST

    # mount ISo file to begin copying data to USB
    mount_ISO

    # copy files from mounted iso to temporary work directories
    copy_ISO_to_tmp

    # enable union mounting of persistance partition over live partition
    enable_persistance

    # install grub2 to device root and efi directory
    install_grub_to_image

    # install syslinux to usb for legacy booting
    copy_syslinux_to_MBR
    install_syslinux

    # configure grub2 for hybrid booting
    setup_boot_config

    # clean up and exit gracefully
    clean
fi
