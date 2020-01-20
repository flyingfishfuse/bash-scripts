

parted /dev/sde --script mkpart EFI fat16 1MiB 10MiB
parted /dev/sde --script mkpart live fat16 10MiB 3GiB
parted /dev/sde --script mkpart persistence ext4 3GiB 100%
parted /dev/sde --script set 1 msftdata on
parted /dev/sde --script set 2 legacy_boot on
parted /dev/sde --script set 2 msftdata on

mkfs.vfat -n EFI /dev/sdX1
mkfs.vfat -n LIVE /dev/sdX2
mkfs.ext4 -F -L persistence /dev/sde3

mkdir /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
mount /dev/sdf1 /tmp/usb-efi
mount /dev/sdf2 /tmp/usb-live
mount /dev/sdf3 /tmp/usb-persistence
mount -oro live.iso /tmp/live-iso
cp -ar /tmp/live-iso/* /tmp/usb-live
echo "/ union" > /tmp/usb-persistence/persistence.conf
grub-install --removable --target=x86_64-efi --boot-directory=/tmp/usb-live/boot/ --efi-directory=/tmp/usb-efi /dev/sdX
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/gptmbr.bin of=/dev/sdX
syslinux --install /dev/sdX2
mv /tmp/usb-live/isolinux /tmp/usb-live/syslinux
mv /tmp/usb-live/syslinux/isolinux.bin /tmp/usb-live/syslinux/syslinux.bin
mv /tmp/usb-live/syslinux/isolinux.cfg /tmp/usb-live/syslinux/syslinux.cfg
sed --in-place 's#isolinux/splash#syslinux/splash#' /tmp/usb-live/boot/grub/grub.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 persistence/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg
sed --in-place '0,/boot=live/{s/\(boot=live .*\)$/\1 keyboard-layouts=en locales=en_US/}' /tmp/usb-live/boot/grub/grub.cfg /tmp/usb-live/syslinux/menu.cfg
sed --in-place 's#isolinux/splash#syslinux/splash#' /tmp/usb-live/boot/grub/grub.cfg
umount /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso
rmdir /tmp/usb-efi /tmp/usb-live /tmp/usb-persistence /tmp/live-iso



moop@debian:~$ sudo dc3dd if=/dev/sdc hof=./MOOPBIAN/moopbian_live_full.img verb=on hash=md5

#####################################
#  if hash no match do it again baby
#####################################

dc3dd 7.2.646 started at 2016-11-04 07:28:11 +0000
compiled options:
command line: dc3dd if=/dev/sdc hof=./MOOPBIAN/moopbian_live_full.img verb=on hash=md5
device size: 30031872 sectors (probed),   15,376,318,464 bytes
sector size: 512 bytes (probed)
 15376318464 bytes ( 14 G ) copied ( 100% ),  830 s, 18 M/s
 15376318464 bytes ( 14 G ) hashed ( 100% ),  131 s, 112 M/s

input results for device `/dev/sdc':
   30031872 sectors in
   0 bad sectors replaced by zeros
   4383ee5b3f1b3d70418375ea72afc00e (md5)

output results for file `./MOOPBIAN/moopbian_live_full.img':
   30031872 sectors out
   [ok] 4383ee5b3f1b3d70418375ea72afc00e (md5)

dc3dd completed at 2016-11-04 07:42:01 +0000

#########################
#   HASH MATCH BABY
#########################


##################################################
#
#     FIND THE OFFSET AND MOUNT THAT HUNK'A'LOVE
#	offset = start_sector * block_size
#
##################################################

moop@debian:~/MOOPBIAN$ sudo fdisk -l ./moopbian_live_full.img
Disk ./moopbian_live_full.img: 14.3 GiB, 15376318464 bytes, 30031872 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 2A36C9BF-CDE0-46BF-852E-35AED124EF06

Device                      Start      End  Sectors  Size Type
./moopbian_live_full.img1    2048    20479    18432    9M Microsoft basic data
./moopbian_live_full.img2   20480  6291455  6270976    3G Microsoft basic data
./moopbian_live_full.img3 6291456 30029823 23738368 11.3G Linux filesystem



moop@debian:~/MOOPBIAN$ file ./moopbian_live_full.img
./moopbian_live_full.img: DOS/MBR boot sector; partition 1 : ID=0xee, start-CHS (0x0,0,1),
 end-CHS (0x3ff,254,63), startsector 1, 30031871 sectors

moop@debian:~/MOOPBIAN$ sudo mount -o ro,loop,offset=512 ./moopbian_live_full.img moopbian_img_mount/



##################################################
#
#     COPY S**T TO THE WORK DIRECTORY
#
#
##################################################

moop@debian:~/MOOPBIAN$ sudo rsync --progress \
 '/home/moop/MOOPBIAN/root-partition/live/filesystem.squashfs'\
 '/home/moop/MOOPBIAN/root-partition/live/initrd.img-4.9.0-3-amd64'\
 '/home/moop/MOOPBIAN/root-partition/live/vmlinuz-4.9.0-3-amd64'\
 '/home/moop/MOOPBIAN/root-partition/live/config-4.9.0-3-amd64'\
 '/home/moop/MOOPBIAN/root-partition/live/System.map-4.9.0-3-amd64'\
 ./
