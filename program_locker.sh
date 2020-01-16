#!/bin/bash
## $PROG create group and lock program to user in that group
## Compatible with bash and dash/POSIX
## 
## Usage: $PROG [OPTION...] [COMMAND]...
## Options:
##   -i, --log-info           Set log level to info                             (Default)
##   -u, --user USER          The username to be locked                         (Default: moop)
##   -p, --program PROGRAM    The program to lock out                           (Default: /usr/bin/lolcat)
##   -g, --group GROUP        The group to lock out                             (Default: moop)
##
## Commands:
##   -h, --help             Displays this help and exists <-- no existential crisis here!
##   -v, --version          Displays output version and exits
## Example:
##   $PROG -u metasploit -g metasploit -p /usr/bin/msfconsole 
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

echo"=================================================="
echo"=================================================="
echo"==========MAKE SURE THIS IS CORRECT!!!!!=========="
echo"=================================================="
echo"==================================================\n\n"
echo "${USER} ALL=(root) ${PROGRAM}"

locker()
{
    sudo -S addgroup $GROUP
    sudo -S chmod 750 $PROGRAM
    sudo -S chown $USER:$GROUP $PROGRAM
    sudo -S adduser $USER $GROUP 
    echo "${USER} ALL=(root) ${PROGRAM}" >> /etc/sudoers
}
PS3="IS THIS CORRECT?!?!?:>"
select option in correct not_correct quit
do
	case $option in
    	correct) 
            #this is so fucking dangerous
            locker
            break;;
        no) 
            echo "Looks like something is preventing the script from working right\n you have to this manually"
            break;;
        quit)
        	break;;
    esac
    
done

