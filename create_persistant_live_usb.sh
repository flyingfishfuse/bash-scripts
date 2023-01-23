#!/bin/bash

PROG=${0##*/}
LOGFILE="$0.logfile"
#die() { echo $@ >&2; exit 2; }

show_help(){
cat <<EOF 
 $PROG create_live_usb.sh 
 This program makes a live USB with persistance utilizing syslinux
 CURRENTLY ONLY 64-BIT BOOTLOADER IS WORKING
 Usage: $PROG [OPTION...] [COMMAND]...
 Options:
  --a, --architecture ARCH    amd64,x86,arm                                (Required, Default: amd64 )

  --l, --iso_path ISO_PATH    full system path to live iso file
                              e.g. (/home/USER/Downloads/debian.iso)       (Default: /home/$USER/Downloads/debian.iso )

  --d, --device DEVICE        The device to install the Distro to          (Required, Default: NONE )

  --g, --get_new_iso          Downloads Debian iso from official sources   (Default: NONE )
                              saves to /home/USER/Downloads/debian.iso
                              use this function alone, then run the 
                              program again with the expected args for
                              creation of a live USB

  --d, --use_debootstrap      Uses debootstrap to generate an iso of       (Default: NONE )
                              Debian that can be tailored to your 
                              specifications

  --s, --chroot_script        script to run on chroot when generating a    (Default: NONE )
                              custom Debian iso file, this must be a 
                              system path

  --a, --architecture         debootstrap/grub ARCH (amd64,x86,arm)        (Default: amd64 )

  --f, --loop_device          loop device to create for mounting of images (DEFAULT: /dev/loop0)

  --b, --build_folder         full system path to folder you want to build the iso in ( Default: /home/$USER/build_folder )

  --o, --iso_output_location  location to put custom iso file              (Default: /home/$USER/build_folder )

  --c, --custom_iso_name      custom name for custom iso                   (Default: custom_debian )

  --r, --root_password        root password for chroot container           (Default: password )

  --n, --new_username         username for new debootstrap creations       (Default: $USER )

  --p, --new_user_password    password for new debootstrap creations       (Default: password )
  
  --m, --repository_mirror    debian mirror to use for apt in the chroot container (DEFAULT: "https://deb.debian.org/debian/" )
  
  --v, --release              debian version to create/download            (DEFAULT: stable)
  
  --e , --includes            Extra software to install in chroot for custom ISO (DEFAULT: linux-image-amd64,grub-pc,ssh,vim)
 
  --h, --show_help            Displays this help and exits

   Thanks:
    That one person on stackexchange who answered everything in one post.
    The internet and search engines (except google, it ignores half of what you type) !

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
[-]     the official debian mirrors. This option is ignored when the option to
[-]     use "debootstrap" is given. That option creates an iso.
[-]     
[-]         example: /home/user/Downloads/debian.iso
[-]
[-]     Device path of unpartitioned device
[-] 
[-]         example: /dev/sdb
[-]
###############################################################################
EOF

green="$(tput setaf 2)"
red=$(tput setaf 1)
yellow=$(tput setaf 3)

# prints color strings to terminal
# Argument $1 = message
# Argument $2 = color
cecho ()
{
  local default_msg="[-] No message passed."
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
cecho "$1" "$red" 1>&2 >> "$LOGFILE"
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

# creates temporary directories for mounting of partitions
set_temp_dirs()
{
temp_efi_dir="/tmp/usb-efi"
temp_live_dir="/tmp/usb-live"
temp_persist_dir="/tmp/usb-persistence"
temp_live_iso_dir="/tmp/live-iso"
}

# create build hierarchy and image file for dd operations
# works, dont change
make_files()
{
# create the build folder
echo "[+] Creating $build_folder"
mkdir "$build_folder"

# create the image file
echo "[+] Creating $iso_output_location/$custom_iso_name.img"
touch "$iso_output_location/$custom_iso_name.img"
}

# make image file and mount on loop device for chroot operations
# works, dont change
make_disk()
{
# fill image file to correct size with all zeros
dd if=/dev/zero of= "$iso_output_location/$custom_iso_name.img" bs=$block_size count=$block_count
# create loop device out of image file
sudo losetup "$loop_device" "$iso_output_location/$custom_iso_name.img"
# create schema
sudo parted -s "$loop_device" mklabel gpt
# create partition
sudo parted -s "$loop_device" mkpart primary 1MiB 100%
# create ext4 filesystem
echo "y
" | sudo mkfs.ext4 "$loop_device"
# mount loop device on iso build folder
sudo mount "$loop_device""$build_folder"
}

build_new_os()
{
# begin pulling all necessary data for debian install
# if this fails, depending on the fail it might work if run a second time
# TODO: check for "E: Couldn't download packages:" and interrupt to run again

# these NEED to be run, you WILL encounter an error if packages mismatch
sudo apt update -y
sudo apt upgrade -y 

# begin the pull and install
sudo debootstrap --arch "$architecture" --include="$includes" "$release" "$build_folder" "$repository_mirror"
# copy files necessary for networking and package managment
sudo cp /etc/resolv.conf "$build_folder/etc/resolv.conf"
sudo cp /etc/apt/sources.list "$build_folder/etc/apt/"
sudo cp /etc/hosts "$build_folder/etc/hosts"
}

prepare_chroot()
{
#mount --make-rslave --rbind /proc /mnt/proc
#mount --make-rslave --rbind /sys /mnt/sys
#mount --make-rslave --rbind /dev /mnt/dev
#mount --make-rslave --rbind /run /mnt/run
#chroot /mnt /bin/bash
# mount in preparation for chroot
sudo mount -o bind /dev "$build_folder/dev"
sudo mount none -t devpts "$build_folder/dev/pts"
sudo mount -o bind -t proc /proc "$build_folder/proc"
sudo mount -o bind -t sys /sys "$build_folder/sys"
sudo mount --bind /run  "$build_folder/run"
}

#######################################
# Chroots into the iso build folder to
# finish building the filesystem of the
# custom iso image 
# param1: new_username
# param2: new_user_password
# param3: root_password
# param4: optional, bash code to run in
#         chroot
#######################################
chroot_buildup(){
# ROOT USER ONLY
# perform scripted actions in chroot
cat << EOF | sudo chroot "$build_folder"

# add user and set password
echo "$new_user_password
$new_user_password" | adduser "$new_username"

# change root password
echo "$root_password:$root_password" | chpasswd


# this step should be performed inside and outside the chroot
apt update
apt upgrade

# install prerequisites for third party apt installs

apt install --no-install-recommends -y install sudo debconf nano apt-transport-https ca-certificates curl gnupg lsb-release wget curl

#add user to sudoers group
usermod -aG sudo $new_username
EOF

# execute external script inside the chroot to perform actions further
# customizing the live USB being created, this can involve anything you
# wish, so long as it can be scripted
#if $1; then
#    chroot_exec_heredoc $1
#fi
}

teardown_chroot()
{
# unmount chroot pipelines
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts
# detach loop device, now its just a file with no connections or locks
sudo losetup -d /dev/loop0
}

create_bootable_iso()
{
sudo genisoimage -o "$output_iso" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table /

}

debootstrap_process()
{
make_files
make_disk
build_new_os 
prepare_chroot
chroot_buildup
teardown_chroot
create_bootable_iso
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
# options that have arguments should have : after them, before the comma
short_opts="a:i:d:b:o:c:r:n:p:e:m:ugh"
long_opts="architecture:,\
iso_path:,\
device:,\
build_folder,\
iso_output_location,\
custom_iso_name,\
use_debootstrap,\
root_password,\
new_username,\
new_user_password,\
includes,\
repository_mirror,\
get_new_iso,\
help"
#TEMP_OPTS=$(getopt -o a:i:d:gh: --long architecture:,iso_path:,device:,get_new_iso:,help -n 'create_live_usb' -- "$@")
TEMP_OPTS=$(getopt -o ${short_opts} --long ${long_opts} -n 'create_live_usb' -- "$@")

#if [ $? != 0 ] ; then 
#    echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around '$TEMP': they are essential!
eval set -- "$TEMP_OPTS"

while true; do
    case "$1" in
        # debootstrap/grub ARCH (amd64,x86,arm)
        --a | --architecture)        architecture="$2"; shift 2;;
        # path to live iso
        --i | --iso_path)            iso_path="$2"; shift 2;;
        # device to use for liveUSB creation, the usb stick
        --d | --device)              device="$2"; shift 2;;
        # full system path to folder you want to build the iso in
        --b | --build_folder)        build_folder="$2"; shift 2;;
        # location to put custom iso file
        --o | --iso_output_location) iso_output_location"$2"; shift 2;;
        # custom name for custom iso
        --c | --custom_iso_name)     custom_iso_name"$2"; shift 2;;
        # root password for root user in debootstrap chroot container
        --r | --root_password)       root_password="$2"; shift 2;;
        # username for new debootstrap creations
        --n | --new_username)        new_username="$2"; shift 2;;
        # password for new debootstrap creations
        --p | --new_user_password)   new_user_password="$2"; shift 2;;
        # extra software to install in the custom iso
        --e | --includes)            includes="$2"; shift 2;;
        # repository to use for apt downloads
        --m | --repository_mirror)  repository_mirror="$2"; shift 2;;
        # download new debian iso from internet
        --g | --get_new_iso)         get_new_iso;;
        # use debootstrap to create an iso instead of downloading prebuilt image
        --u | --use-debootstrap)     use_debootstrap=true; shift 2 ;;
        # show the help heredocs
        --h | --show_help)           show_help; shift 2 ;;
        # empty options get no action
        --  )                        shift; break ;;
        # no options at all get the help screen
        *   )                        show_help; break ;;
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
# makes an empty disk image using dd
# to achive correct size in gigabytes, maths out "num_GB/1024"
# e.g. 5GB * 1024 == 5120
block_size="1M"
block_count='5120'
# use parted syntax

# these are REQUIRED params
# Print help in case parameters are empty
# -z means non-defined or empty
if [ -z "$architecture" ] || [ -z "$iso_path" ] || [ -z "$device" ]
then
   echo "$empty_required_args_error_message"
else
    # setting defaults if options not given on command line
    if [ -z "$repository_mirror" ] || [ -z "$release" ] || [ -z "$includes" ] || [ -z "$build_folder" ] || \
    [ -z "$root_password" ] || [ -z "$new_username" ] || [ -z "$new_user_password" ] || [ -z "$iso_output_location" ] || \
    [ -z "$custom_iso_name" ] || [ -z "$loop_device" ]
    then
        # folder to create and build iso inside of
        build_folder="/home/$USER/build_folder"
        # what to name the custom iso file
        custom_iso_name="custom_debian.iso"
        # location of output file when building iso
        iso_output_location="$build_folder/$custom_iso_name.iso"
        # root password for root user in debootstrap chroot container
        root_password="password"
        # username for new debootstrap creations
        new_username="moop"
        # password for new debootstrap creations
        new_user_password="password"
        # debian mirror to use for apt in the chroot container
        repository_mirror="https://deb.debian.org/debian/"
        # debian version
        release="stable"
        # packages to include DURING debootstrap
        includes="linux-image-amd64,grub-pc,ssh,vim"
        # loop device to create for mounting of images
        loop_device="/dev/loop0"
    fi
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

    # obtaining the data for an OS from one of two sources
    # whether a premade OS direct from debian mirrors
    # or using the utility "debootstrap" to create an OS in
    # a chroot environment that is usually much smaller
    # and specialized
    if $use_debootstrap; then
        # creates an iso using debootstrap to customize the OS
        debootstrap_process "$new_username" "$new_user_password" "$root_password"
    else
        # mount ISO file to begin copying data to USB
        mount_ISO
    fi
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
