#!/bin/bash
## $PROG 1.0 - Print logs [2017-10-01] // Debo0tstrap Chro0t Generat0r v1 // 
## Compatible with bash and dash/POSIX
## 
## Usage: $PROG [OPTION...] [COMMAND]...
## Options:
##   -i, --log-info           Set log level to info                             (Default)
##   -q, --log-quiet          Set log level to quiet                            (not implemented yet)
##   -u, --user USER          The username to be created                        (Default: moop)
##   -p, --password PASS      The password to said username                     (Default: password)
##   -e, --extra LIST         Space seperated list of extra packages to install (Default: micro)
##   -m, --smacaddress MAC    MAC Address of the Sandbox                        (Default: de:ad:be:ef:ca:fe)
##   -i, --sipaddress IP      IP Address of the Sandbox                         (Default: 192.168.0.3)
##   -h, --sifacename IFACE   Interface name for the Sandbox                    (Default: hakc1)
##   -l, --sandbox_location   Full Path of the Sandbox                          (Default: /home/moop/Desktop/sandbox)
##   -a, --architecture       AMD64, X86, ARM, what-have-you                    (Default: amd64)
##   -c, --compenent          Which repository components are included          (Default: main,contrib,universe,multiverse)
##   -r, --repositorie        The Debian-based repository. E.g. "Ubuntu"        (Default: http://archive.ubuntu.com/ubuntu/)
##
## Commands:
##   -h, --help             Displays this help and exists <-- no existential crisis here!
##   -v, --version          Displays output version and exits
## Examples:
##   $PROG -i myscrip-simple.sh > myscript-full.sh
##   $PROG -r myscrip-full.sh   > myscript-simple.sh
## Thanks:
## https://www.tldp.org/LDP/abs/html/colorizing.html
## That one person on stackexchange who answered everything in one post.
## The internet and search engines!
## 
PROG=${0##*/}
LOG=info
die() { echo $@ >&2; exit 2; }
log_info() {
  LOG=info
}
log_quiet() {
  LOG=quiet
}
log() {
  [ $LOG = info ] && echo "$1"; return 1 ## number of args used
}
#SANDBOX user configuration
user()
{
	USER='moop'
}
password()
{
	PASSWORD='password'
}
extra()
{
	#Watch'ya watch'ya watch'ya want, watch'ya WANT?!?
	EXTRA_PACKAGES='micro'
}
sifacename()
{
	#SANDBOX external network interface configuration
	SANDBOX_IFACE_NAME='hakc1'
}
smacaddress()
{
	SANDBOX_MAC_ADDRESS='de:ad:be:ef:ca:fe'
}
sipaddress()
{
	SANDBOX_IP_ADDRESS='192.168.1.3'
}
sandbox_location()
{
	SANDBOX='/home/moop/Desktop/SANDBOX'
}
architecture()
{
	ARCH='amd64'
}
component()
{
	COMPONENTS='main,contrib,universe,multiverse'
}
respositorie()
{
	REPOSITORY='http://archive.ubuntu.com/ubuntu/'
}
#greps all "##" at the start of a line and displays it in the help text
help() {
  grep "^##" "$0" | sed -e "s/^...//" -e "s/\$PROG/$PROG/g"; exit 0
}
#Runs the help function and only displays the first line
version() {
  help | head -1
}
#Black magic wtf is this
[ $# = 0 ] && help
while [ $# -gt 0 ]; do
  CMD=$(grep -m 1 -Po "^## *$1, --\K[^= ]*|^##.* --\K${1#--}(?:[= ])" go.sh | sed -e "s/-/_/g")
  if [ -z "$CMD" ]; then echo "ERROR: Command '$1' not supported"; exit 1; fi
  shift; eval "$CMD" $@ || shift $? 2> /dev/null

#=========================================================
#            Colorization stuff
#=========================================================
black='\E[30;47m'
red='\E[31;47m'
green='\E[32;47m'
yellow='\E[33;47m'
blue='\E[34;47m'
magenta='\E[35;47m'
cyan='\E[36;47m'
white='\E[37;47m'
     
#Reset text attributes to normal
#without clearing screen.
alias Reset="tput sgr0"
cecho ()
{
	# Argument $1 = message
	# Argument $2 = color
	local default_msg="No message passed."
	#message is first argument OR default
	message=${1:-$default_msg}
	# color is second argument OR white
	color=${2:$white}
	if [$color='lolz']
	then
		echo $message | lolcat
		return
	else
		local default_msg="No message passed."
		# Doesn't really need to be a local variable.
		message=${1:-$default_msg}   # Defaults to default message.
		color=${2:-$black}           # Defaults to black, if not specified.
		echo -e "$color"
		echo "$message"
		Reset                      # Reset to normal.
		return
}  

echo "======================================================================="
echo "=================--Debo0tstrap Chro0t Generat0r--======================"
echo "======================================================================="
echo "==="
LOGFILE='./debootstrap_log.txt'
#HOST network interface configuration that connects to SANDBOX
#in my test this is a Wireless-N Range extender with OpenWRT connected through a Ethernet to USB connector
HOST_IFACE_NAME='enx000ec6527123'
INT_IP='192.168.1.161'
#HOST network interface configuration that connects to Command and Control 
#This is the desktop workstation you aren't using this script on because its stupid to do that.
IF_CNC='eth0'
IF_IP_CNC='192.168.0.44'_
#internet access for the LAN, This is your internet router.
GATEWAY='192.168.0.1'
error_exit()
{
	echo "$1" 1>&2 >> $LOGFILE
	exit 1
}
deboot_first_stage()
{
# Sequential commands with error checking	
	cecho "[+] Beginning Debootstrap" yellow
	sudo debootstrap --components $COMPONENTS --arch $ARCH bionic $SANDBOX $REPOSITORY >> $LOGFILE
	if [ "$?" = "0" ]; then
	    cecho "[+] Debootstrap Finished Successfully!" green
	else
		error_exit "[-]Debootstrap Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi

#resolv.conf copy
	echo "[+] Copying Resolv.conf" yellow
	sudo cp /etc/resolv.conf $SANDBOX/etc/resolv.conf
	if [ "$?" = "0" ]; then
	    cecho "[+] Resolv.conf copied!" green 
	else
		error_exit "[-]Copy Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi

# sources.list copy
    cecho "[+] Copying Sources.list" yellow
	sudo cp /etc/apt/sources.list $SANDBOX/etc/apt/
	if [ "$?" = "0" ]; then
	    cecho "[+] Sources.list copied!" green 
	else
		error_exit "[-]Copy Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi

#mount and bind the proper volumes
# /dev
	cecho "[+] Mounting /dev"  yellow
	sudo mount -o bind /dev $SANDBOX/dev
	if [ "$?" = "0" ]; then
	    cecho "[+] Mounted!" green 
	else
		error_exit "[-]Mount Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi
# /proc
    cecho "[+] Mounting /proc" yellow
	sudo mount -o bind -t proc /proc $SANDBOX/proc
	if [ "$?" = "0" ]; then
	    cecho "[+] Mounted!" green 
	else
		error_exit "[-]Mount Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi
# /sys
    cecho "[+] Mounting /dev" yellow
	sudo mount -o bind -t sys /sys $SANDBOX/sys
	if [ "$?" = "0" ]; then
	    cecho "[+] Mounted!" green 
	else
		error_exit "[-]Mount Failed! Check the logfile!" 1>&2 >> $LOGFILE
	fi
}
#finish setting up the basic system
deboot_second_stage()
{
	sudo chroot $SANDBOX
	useradd $USER 
	passwd  $USER
	login $USER
	sudo -S apt-get update
	sudo -S apt-get --no-install-recommends install wget debconf nano curl
	sudo -S apt-get update  #clean the gpg error message
	sudo -S apt-get install locales dialog  #If you don't talk en_US
	#sudo -S locale-gen en_US.UTF-8  # or your preferred locale
	#tzselect; TZ='Continent/Country'; export TZ  #Configure and use our local time instead of UTC; save in .profile
}
#begin setting up services
deboot_third_stage()
{
	sudo -S apt install $EXTRA_PACKAGES
}
#Makes an interface with iproute1
create_iface_ipr1()
{
	sudo -S modprobe dummy
	sudo -S ip link set name $SANDBOX_IFACE_NAME dev dummy0
	sudo -S ifconfig $SANDBOX_IFACE_NAME hw ether $SANDBOX_MAC_ADDRESS
}
#Makes an interface with iproute2
create_iface_ipr2()
{
	ip link add $SANDBOX_IFACE_NAME type veth
}
del_iface1()
{
	sudo -S ip addr del $SANDBOX_IP_ADDRESS/24 brd + dev $SANDBOX_IFACE_NAME
	sudo -S ip link delete $SANDBOX_IFACE_NAME type dummy
	sudo -S rmmod dummy
}
#Delets the SANDBOX Interface
del_iface2()
{
	ip link del $SANDBOX_IFACE_NAME
}
#run this from the HOST
setup_host_networking()
{
	#Allow forwarding on HOST IFACE
	sysctl -w net.ipv4.conf.$HOST_IF_NAME.forwarding=1
	#Allow from sandbox to outside
	iptables -A FORWARD -i $SANDBOX_IFACE_NAME -o $HOST_IFACE_NAME -j ACCEPT
	#Allow from outside to sandbox
	iptables -A FORWARD -i $HOST_IFACE_NAME -o $SANDBOX_IFACE_NAME -j ACCEPT
}
#this is a seperate "computer", The following is in case you want to setup another
#virtual computer inside this one and allow to the outside
sandbox_forwarding()
{
	#Allow forwarding on Sandbox IFACE
	#sysctl -w net.ipv4.conf.$SANDBOX_IFACE_NAME.forwarding=1
	#Allow forwarding on Host IFACE
	#Allow from sandbox to outside
	#iptables -A FORWARD -i $SANDBOX_IFACE_NAME -o $HOST_IFACE_NAME -j ACCEPT
	#Allow from outside to sandbox
	#iptables -A FORWARD -i $HOST_IFACE_NAME -o $SANDBOX_IFACE_NAME -j ACCEPT
}
#run this from the Host
establish_network()
{
	# 1. Delete all existing rules
	iptables -F
	# 2. Set default chain policies
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT DROP
	# 4. Allow ALL incoming SSH
	iptables -A INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -o eth0 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
	# Allow incoming HTTPS
	iptables -A INPUT -i eth0 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -o eth0 -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
	# 19. Allow MySQL connection only from a specific network
#iptables -A INPUT -i eth0 -p tcp -s 192.168.200.0/24 --dport 3306 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -o eth0 -p tcp --sport 3306 -m state --state ESTABLISHED -j ACCEPT
# 23. Prevent DoS attack
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT




}
############################
##--	Menu System		--##
############################

PS3="Choose your doom:>"
select option in sandbox_connect setup_network quit
do
	case $option in
    	sandbox_connect) 
			connect_sandbox
        setup_network) 
            establish_network
        quit)
        	break;;
    esac
done

exit
