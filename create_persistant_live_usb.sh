#!/bin/bash
# shellcheck disable=SC2024
PROG=${0##*/}
LOGFILE="$0.logfile"
script_name=$0
#script_full_path=$(dirname "$script_name")
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
                              system path, use this option to further
                              customize the liveUSB like installing 
                              kubernetes or docker or whatever!

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

# put short options after -o without commas
# put long options after --long, with commas
# options that have arguments should have : after them, before the comma
short_opts="a:i:d:b:o:c:r:n:p:e:m:s:ugh"
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
chroot_script,\
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
        # script to run in chroot after initial setup
        --s | --chroot_script)      chroot_script="$2"; shift 2;;
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

# this section is for arrays used when selecting extra sets of software to install in the live OS
c_dev_package_list=("man-db" \
"manpages" \
"manpages-dev" \
"manpges-posix-dev" \
"gdb" \
"lldb" \
"valgrind" \
"strace" \
"bison" \
"flex" \
"clang" \
"clang-tidy" \
"clang-format" \
"astyle" \
"cmake" \
"cmake-doc" \
)

install_prerequisite_packages()
{
sudo apt-get install \
    binutils \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools
}
#set_defaults()
##{
## folder to create and build iso inside of
#build_folder="/home/$USER/build_folder"
## what to name the custom iso file
#custom_iso_name="custom_debian.iso"
## location of output file when building iso
#iso_output_location="$build_folder/$custom_iso_name.iso"
## root password for root user in debootstrap chroot container
#root_password="password"
## username for new debootstrap creations
#new_username="moop"
## password for new debootstrap creations
#new_user_password="password"
## debian mirror to use for apt in the chroot container
#repository_mirror="https://deb.debian.org/debian/"
## debian version
#release="stable"
## packages to include DURING debootstrap
#includes="linux-image-amd64,grub-pc,ssh,vim"
## script to run inside chroot for extra customizations
#chroot_script="/home/$USER/chroot_script.sh"
## loop device to create for mounting of images
#loop_device="/dev/loop0"
## external script to run in chroot after initial operations
#}
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

}

# use DD to create blank image for mounting
custom_create_blank_image(){
    # create the image file
    echo "[+] Creating $iso_output_location/$custom_iso_name.img"
    touch "$iso_output_location/$custom_iso_name.img"

    # fill image file to correct size with all zeros
    if sudo dd if=/dev/zero of= "$iso_output_location/$custom_iso_name.img" bs=$block_size count=$block_count &>> "$LOGFILE";then
        cecho "[+] Blank image created using dd" "$green"
    else
        cecho "[-] failed to create blank image using dd, check the logfile" "$red"
        cecho "[-] EXITING!" "$red"
        exit
    fi
}

# create new loop device and mount empty image on it
custom_create_loop_device_by_mounting_image(){
if sudo losetup "$loop_device" "$iso_output_location/$custom_iso_name.img" &>> "$LOGFILE";then
    cecho "[+] Loop device $loop_device has been created and image file has been mounted on it" "$green"
else
    cecho "[-] Failed to mount image on new loop device, check the logfile" "$red"
    cecho "[-] EXITING!" "$red"
    exit
fi }

# create gpt partition table on iso image
custom_create_partition_table_on_loop_device()
{
if sudo parted -s "$loop_device" mklabel gpt &>> "$LOGFILE";then
    cecho "[+] GPT partitioning schema created on $loop_device" "$green"
else
    cecho "[-] Failed to initialize partionting scheme 'GPT' on $loop_device, check the logfile" "$red"
    cecho "[-] EXITING!" "$red"
    exit
fi
}
# initialize primary partition
custom_create_primary_partition()
{
if sudo parted -s "$loop_device" mkpart primary 1MiB 100% &>> "$LOGFILE";then
    cecho "[+] EXT4 filesystem created " "$green"
else
    cecho "[+] Failed to create EXT4 filesystem on $loop_device, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi
}

# create ext4 filesystem on custom iso image
custom_create_ext4_filesystem()
{
if echo "y
" | sudo mkfs.ext4 "$loop_device" &>> "$LOGFILE";then
    cecho "[+] EXT4 filesystem created " "$green"
else
    cecho "[+] Failed to create EXT4 filesystem on $loop_device, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi
}

# mount loop device on iso build folder
mount_loop_device_on_build_folder()
{
if sudo mount "$loop_device" "$build_folder"; then
    cecho "[+] $build_folder mounted on $loop_device" "$green"
else
    cecho "[+] Failed to mount $build_folder on $loop_device, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi
}

mount_for_chroot()
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

build_new_os()
{
# begin pulling all necessary data for debian install
# if this fails, depending on the fail it might work if run a second time
# TODO: check for "E: Couldn't download packages:" and interrupt to run again

# these NEED to be run, you WILL encounter an error if packages mismatch

# update package information
if sudo apt update -y &>> "$LOGFILE"
then
    cecho "[+] Apt repo data updated" "$green"
else
    cecho "[-] Failed to update system package information, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi

# upgrade packages in preparation for debootstrap and chroot operations
if sudo apt upgrade -y &>> "$LOGFILE"
then
    cecho "[+] System Packages Updated" "$green"
else
    cecho "[-] Failed to update system packages, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi

# begin the pull and install
if sudo debootstrap --arch "$architecture" --include="$includes" "$release" "$build_folder" "$repository_mirror" &>> $LOGFILE
then
    cecho "[+] Debootstrap has created an OS structure in the guest hierarchy" "$green"
else
    cecho "[-] debootstrap process failed, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi

# copy dns info to enable networking
if sudo cp /etc/resolv.conf "$build_folder/etc/resolv.conf" &>> $LOGFILE
then
    cecho "[+] resolve.conf copied to guest" "$green"
else
    cecho "[-] Failed to copy resolve.conf to guest, check the logfile " "$red"
    cecho "[-] EXITING!"
    exit
fi

# copy apt package sources
if sudo cp /etc/apt/sources.list "$build_folder/etc/apt/" &>> $LOGFILE
then
    cecho "[+] sources.list copied to guest" "$green"
else
    cecho "[-] failed to copy sources.list to guest, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi


if sudo cp /etc/hosts "$build_folder/etc/hosts" &>> "$LOGFILE"
then
    cecho "[+] Hosts file copied to guest" "$green"
else
    cecho "[-] Failed to copy hosts file to guest, check the logfile" "$red"
    cecho "[-] EXITING!"
    exit
fi
}

#######################################
# gets filename by stripping path
# param1: full path to file
get_file_name_no_path()
{
#get file name without the path:
filename=$(basename -- "$1")
#extension="${filename##*.}"
filename="${filename%.*}"
# Alternatively, you can focus on the last '/' of the path instead of the '.''
# which should work even if you have unpredictable file extensions:
#filename="${1##*/}"
echo "$filename"
}

run_external_script_in_chroot1()
{
# get name of extra script file
script_name=$(basename -- "$chroot_script")
# copy to chroot directory
sudo cp "$chroot_script" "$build_folder"
# step into container make script executable and run script
sudo chroot "$build_folder" "sh -c 'chmod +x ${script_name} && ./${script_name}'"
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

# this step should be performed inside and outside the chroot
apt update
apt upgrade

apt-get install -y libterm-readline-gnu-perl systemd-sysv

apt install --no-install-recommends -y install sudo debconf nano apt-transport-https ca-certificates curl gnupg lsb-release wget curl \
xorg xinit openbox fluxbox gparted \
casper \
lupin-casper \
discover \
laptop-detect \
os-prober \
network-manager \
resolvconf \
net-tools \
wireless-tools \
wpagui \
locales \
grub-common \
grub-gfxpayload-lists \
grub-pc \
grub-pc-bin \
grub2-common \
git \
thunar \
nvim \
tmux \
exa \

# The /etc/machine-id file contains the unique machine ID of the local system 
# that is set during installation or boot. The machine ID is a single 
# newline-terminated, hexadecimal, 32-character, lowercase ID. When decoded 
# from hexadecimal, this corresponds to a 16-byte/128-bit value. 
# This ID may not be all zeros.

dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id

# dpkg-divert is the utility used to set up and update the list of diversions.

dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

# configure network manager
cat << NET > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=false
NET
# apply new configuration
dpkg-reconfigure network-manager


# add user and set password
echo "$2
$2" | adduser "$1"

# change root password
echo "$3:$3" | chpasswd

#add user to sudoers group
usermod -aG sudo $1

EOF

}

# adds vscode installtion to the pipeline
chroot_install_vscode()
{
cat << EOF | sudo chroot "$build_folder"
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg

install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/

echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list

rm microsoft.gpg
EOF
}

#######################################
# Installs software development tooling
# param1: array of package names for apt install
chroot_install_development_tooling()
{
if [ "$1" == 1 ]; then
cat << PACKAGES | sudo chroot "$build_folder"
# switch to new user
su - $new_username

# use sudo to cache password
echo $new_user_password | sudo -S echo "Sudo password used to cache for operations"

sudo apt install \
$(
    for s in "${1[@]}"
    do
      echo "$s \\"
    done
)

PACKAGES
fi
}
test_array=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l")
test_heredoc=$(cat << TEST | chroot $build_folder
$(
    for s in "${test_array[@]}"
    do
      #printf "%s \\" "$s \n"
      echo "$s"
    done
)
TEST
)
echo "$test_heredoc"
teardown_chroot()
{
# unmount chroot pipelines
#umount -lf /proc
#umount -lf /sys
#umount -lf /dev/pts
cat << TEARDOWN | sudo chroot "$build_folder"
apt-get clean

truncate -s 0 /etc/machine-id

dpkg-divert --rename --remove /sbin/initctl

rm /sbin/initctl
rm /var/lib/dbus/machine-id
rm -rf /tmp/* ~/.bash_history

umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0
exit
TEARDOWN

if sudo umount "$build_folder/dev";then
    cecho "[+] Unmounted /dev" "$green"
else
    cecho "[-] Failed to unmount /dev" "$red"
fi

if sudo umount "$build_folder/dev/pts";then
    cecho "[+] Unmounted /dev/pts" "$green"
else
    cecho "[-] Failed to unmount" "$red"
fi

if sudo umount "$build_folder/proc";then
    cecho "[+] Unmounted /proc" "$green"
else
    cecho "[-] Failed to unmount /proc" "$red"
fi

if sudo umount "$build_folder/sys";then
    cecho "[+] Unmounted /sys" "$green"
else
    cecho "[-] Failed to unmount /sys" "$red"
fi

if sudo umount "$build_folder/run";then
    cecho "[+] Unmounted /run" "$green"
else
    cecho "[-] Failed to unmount /run" "$red"
fi
# detach loop device, now its just a file with no connections or locks
if sudo losetup -d "$loop_device"; then
    cecho "[+] Detached loop device $loop_device" "$green"
else
    cecho "[-] Failed to detach loop device" "$red"
fi
}

# creates the final iso file by packing up the chroot directory
#not done
create_bootable_iso()
{
mkdir -p "$temp_live_iso_dir"/{casper,isolinux,install}

# move kernel and initial ramdisk and EFI programs from the debootstrap folder to the iso build folder
sudo cp "$build_folder"/boot/vmlinuz-**-**-generic "$temp_live_iso_dir"/casper/vmlinuz
sudo cp "$build_folder"/boot/initrd.img-**-**-generic "$temp_live_iso_dir"/casper/initrd
sudo cp "$build_folder"/boot/memtest86+.bin "$temp_live_iso_dir"/install/memtest86+

#get memtest
wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O "$temp_live_iso_dir"/install/memtest86-usb.zip

#install memtest
unzip -p "$temp_live_iso_dir"/install/memtest86-usb.zip memtest86-usb.img > "$temp_live_iso_dir"/install/memtest86

# clean up memtest
rm -f "$temp_live_iso_dir"/install/memtest86-usb.zip

#create squashfs
sudo mksquashfs squashfs-root filesystem.squashfs -b 1048576 -comp xz -Xdict-size 100%

sudo genisoimage -o "$iso_output_location/$custom_iso_name.iso" \
-b isolinux/isolinux.bin \
-c isolinux/boot.cat \
-no-emul-boot \
-boot-load-size 4 \
-boot-info-table /
#Used genisoimage -r -V "Ubuntu" \
# -cache-inodes -J -l \
#-b isolinux/isolinux.bin \
#-c isolinux/boot.cat \
#-no-emul-boot \
#-boot-load-size 4 \
#-boot-info-table \
#-o ironpig.iso \
#FC5/ 
#
# to build a .iso (FC5 being the directory I extracted ubuntu.iso into).
}

# creates /dev/xx1 EFI boot partition
# This creates the basic disk structure of an EFI disk with a single OS.
create_EFI_partition()
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
create_LIVE_partition()
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
create_PERSISTANT_partition()
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
set_flags_on_USB_partitions()
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

create_EFI_VFAT_file_systems_on_USB()
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
create_LIVE_VFAT_filesystem_on_USB()
{
cecho "[+] creating vfat on LIVE partition" "$green"
if sudo mkfs.vfat -n LIVE "${device}"2 &>> "$LOGFILE"; then
    cecho "[+] vfat filesystem created on LIVE partition" "$green"
else
    cecho "[+] Error creating filesystem, check the logfile" "$red"
fi
}

create_persistant_filesystem_on_USB()
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
create_temp_work_dirs_on_HOST()
{
# create the build folder
echo "[+] Creating $build_folder"
if mkdir "$build_folder" &>> "$LOGFILE"; then
    cecho "[+] Build folder created" "$green"
else
    cecho "[+] ERROR: Failed to create temporary work directory, check the logfile" "$red"
    exit
fi
# create the temp directories for moving files to hardware device
cecho "[+] creating temporary work directories " "$green"
if sudo mkdir "$temp_efi_dir" "$temp_live_dir" "$temp_persist_dir" "$temp_live_iso_dir" &>> "$LOGFILE"; then
    cecho "[+] Temporary work directories created" "$green"
else
    cecho "[+] ERROR: Failed to create temporary work directories, check the logfile" "$red"
    exit
fi
}

# Mounting those directories on the newly created filesystem
mount_EFI_on_HOST()
{
cecho "[+] mounting EFI partition on temporary work directory" "$green"
if sudo mount "$device"1 "$temp_efi_dir" &>> "$LOGFILE";then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+]  ERROR: Failed to mount partition, check the logfile" "$red"
    exit
fi
}

mount_LIVE_on_HOST()
{
cecho "[+] mounting LIVE partition on temporary work directory" "$green"
if sudo mount "$device"2 "$temp_live_dir" &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition , check the logfile" "$red"
    exit
fi
}

mount_PERSIST_on_HOST()
{
cecho "[+]  mounting persistance partition on temporary work directory" "$green"
if mount "$device"3 "$temp_persist_dir" &>> "$LOGFILE"; then
    cecho "[+] partition mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount partition, check the logfile" "$red"
fi
}

# mounts iso on temporary directory
#param1: path to iso for mounting on temp directory
mount_ISO_on_HOST()
{
# Mount the ISO on a temp folder to get the files moved
cecho "[+] Mounting ISO file on temporary directory " "$green"
if sudo mount -oro "$1" "$temp_live_iso_dir" &>> "$LOGFILE";then
    cecho "[+] ISO file has been successfully mounted" "$green"
else
    cecho "[+] ERROR: Failed to mount live iso, check the logfile" "$red"
fi
}

copy_ISO_to_LIVE()
{
# copy files from live iso to live partition
if sudo cp -ar "$temp_live_iso_dir"/* "$temp_live_dir" &>> "$LOGFILE";then
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
check_args()
{
if [ -z "$architecture" ] || [ -z "$iso_path" ] || [ -z "$device" ]
then
   echo "$empty_required_args_error_message"
else
    # setting defaults if options not given on command line
    if [ -z "$repository_mirror" ]
    then
        # debian mirror to use for apt in the chroot container
        repository_mirror="https://deb.debian.org/debian/"
    fi
    if [ -z "$release" ] 
    then
        # debian version
        release="stable"   
    fi
    if [ -z "$includes" ]
    then
        # packages to include DURING debootstrap
        includes="linux-image-amd64,grub-pc,ssh,vim"    
    fi
    if [ -z "$build_folder" ]
    then
        # folder to create and build iso inside of
        build_folder="/home/$USER/build_folder"
    fi
    if 
    [ -z "$root_password" ]
    then
        # root password for root user in debootstrap chroot container
        root_password="password"    
    fi
    if [ -z "$new_username" ]
    then
        # username for new debootstrap creations
        new_username="moop"    
    fi
    if [ -z "$new_user_password" ]
    then
        # password for new debootstrap creations
        new_user_password="password"
    fi
    if [ -z "$iso_output_location" ]
    then
        # location of output file when building iso
        iso_output_location="$build_folder/$custom_iso_name.iso"
    fi
    if [ -z "$custom_iso_name" ]
    then
        # what to name the custom iso file
        custom_iso_name="custom_debian.iso"
    fi
    if [ -z "$loop_device" ]
    then
        # loop device to create for mounting of images
        loop_device="/dev/loop0"
    fi
    if [ -z "$chroot_script_path" ]
    then
        # script to run inside chroot for extra customizations
        chroot_script="/home/$USER/chroot_script.sh"
    #set_defaults
    fi
fi
}
#######################################
# CUSTOM ISO CFLOW
# make image file and mount on loop device
# for chroot operations
# param1: new_username
# param2: new_user_password
# param3: root_password
custom_make_disk()
{
    #create the blank image
    custom_create_blank_image
    # mount image as loop device
    custom_create_loop_device_by_mounting_image
    # create gpt partition table
    custom_create_partition_table_on_loop_device
    # initialize a primary partition
    custom_create_primary_partition
    # create ext4 filesystem
    custom_create_ext4_filesystem
    # mount loop device on build folder to build into OS
    # using debootstrap
    mount_loop_device_on_build_folder
    # uses debootstrap to create pre-OS in chroot directory
    build_new_os
    # mounts all chroot requisite host directories in build folder
    mount_for_chroot
    # performs a chroot and creates new user and sets passwords
    if chroot_buildup "$1" "$2" "$3";then
        cecho "[+] Chroot finished" "$green"
    # unmounts all host directories from chroot to begin next step
    if teardown_chroot;then
        cecho "[-] Chroot teardown complete" "$green"
    fi
    else
        cecho "[-] Failed to modify in chroot environment, check the logfile" "$red"
    fi
    # creates an iso to use in the live USB creation
    create_bootable_iso
}
main()
{
    ###################################
    #
    # creates temporary work directories
    set_temp_dirs
    install_prerequisite_packages

###############################################################################
# These are actions applied to the USB device that will be used as a LIVE os
###############################################################################
    # creates efi partition
    create_EFI_partition
    # creates live os partition
    create_LIVE_partition
    # creates persistant data partition
    create_PERSISTANT_partition
    
    # sets required flags on all partitions
    set_flags_on_USB_partitions

    # create filesystems for EFI, live, and persistant partitions
    create_EFI_VFAT_file_systems_on_USB
    create_LIVE_VFAT_filesystem_on_USB
    create_persistant_filesystem_on_USB

###############################################################################
# These are actions applied to the HOST system that is creating the Live OS
###############################################################################

    # create temporary work directories for copying of files and mounting
    # of filesystems
    create_temp_work_dirs_on_HOST

    # mount the partitions on the temporary work directories
    mount_EFI_on_HOST
    mount_LIVE_on_HOST
    mount_PERSIST_on_HOST

###############################################################################
# This is the branch where it will either use debootstrap or a prebuilt ISO
###############################################################################
    # obtaining the data for an OS from one of two sources
    # whether a premade OS direct from debian mirrors
    # or using the utility "debootstrap" to create an OS in
    # a chroot environment that is usually much smaller
    # and specialized
    if $use_debootstrap; then
        # creates an iso using debootstrap to customize the OS
        # this places the iso in the location specified as $iso_path
        custom_make_disk "$new_username" "$new_user_password" "$root_password"
    else
        # mount ISO file to begin copying data to USB
        mount_ISO  "$iso_path"
    fi
    # copy files from mounted iso to temporary work directories
    copy_ISO_to_LIVE

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
}
