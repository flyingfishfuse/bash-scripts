#!/bin/bash
## $PROG create group and lock program to user in that group
## Compatible with bash and dash/POSIX
## 
## Usage: $PROG [OPTION...] [COMMAND]...
## Options:
##   -i, --log-info           Set log level to info                             (Default)
##   -q, --log-quiet          Set log level to quiet                            (not implemented yet)
##   -u, --user USER          The username to be created                        (Default: moop)
##   -p, --password PASS      The password to said username                     (Default: password)
##   -e, --extra LIST         Space seperated list of extra packages to install (Default: lolcat)
##   -m, --smacaddress MAC    MAC Address of the Sandbox                        (Default: de:ad:be:ef:ca:fe)
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
user()
{
	USER='moop'
}
program()
{
	PROGRAM='moop'
}
group()
{
	GROUP='moop'
}

program=wat
group=wat
sudo -S addgroup $GROUP
sudo -S chmod 750 $PROGRAM
sudo -S chown $USER:$GROUP $PROGRAM
sudo -S adduser $USER $GROUP 

echo"=================================================="
echo"=================================================="
echo"==========MAKE SURE THIS IS CORRECT!!!!!=========="
echo"=================================================="
echo"=================================================="
echo "${USER} ALL=(root) ${PROGRAM}"

PS3="IS THIS CORRECT?!?!?:>"
select option in correct not_correct quit
do
	case $option in
    	correct) 
            #this is so fucking dangerous
			echo "${USER} ALL=(root) ${PROGRAM}" >> /etc/sudoers
            break;;
        no) 
            echo "Looks like something is preventing the script from working right\n you have to this manually"
            break;;
        quit)
        	break;;
    esac
    
done

