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

# Reset text attributes to normal
# without clearing screen.
alias Reset="tput sgr0"

# Argument $1 = message
# Argument $2 = color
cecho ()
{
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

cecho"==================================================" "lolz"
cecho"==================================================" "lolz"
cecho"==========MAKE SURE THIS IS CORRECT!!!!!==========" $red
cecho"==================================================" "lolz"
cecho"==================================================\n\n" "lolz"
cecho "${USER} ALL=(root) ${PROGRAM}"

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
            cecho "Looks like something is preventing the script from working right\n you have to this manually" $yellow
            break;;
        quit)
        	break;;
    esac
    
done

