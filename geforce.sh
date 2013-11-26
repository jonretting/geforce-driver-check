#!/bin/bash
# Script for checking for newer Nvidia Display Driver than the one install (x64 win7-win8)

#cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads1" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror

error() {
	echo "Error: $1"
	exit 1
}

# check for PnPutil.exe
hash PnPutil || error "Fatal"

# check if DOWNLOADDIR exists
[[ -d "$DOWNLOADDIR" ]] || error "Directory not found $DOWNLOADDIR"

# ask function
# takes -y option for auto yes
ask() {
	while true; do
		if [ "${2:-}" = "Y" ]; then
			prompt="Y/n"; default=Y
		elif [ "${2:-}" = "N" ]; then
			prompt="y/N"; default=N
		else
			prompt="y/n"; default=
		fi
		if [ "$1" = "-y" ]; then # Ask the question
			REPLY=Y; default=Y
		else
			echo -ne "$1 "; read -p "[$prompt] " REPLY
			[ -z "$REPLY" ] && REPLY=$default # Default?
		fi
		case "$REPLY" in # Check if the reply is valid
			Y*|y*) return 0 ;;
			N*|n*) return 1 ;;
		esac
	done
}

#hard defaults no edit
LINK="http://www.nvidia.com/Download/processFind.aspx?psid=95&pfid=695&osid=19&lid=1&whql=&lang=en-us"
FILEDATA=$(wget -qO- "$(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1)" | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
FILENAME=$(echo "$FILEDATA" | cut -d '/' -f4)
NEWVER=$(echo "$FILEDATA" | cut -d '/' -f3 | sed -e "s/\.//") # new version info
CURRENTVER=$(PnPutil.exe -e | grep -A 3 "NVIDIA" | grep -A 1 "Display" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//") # current version information
DLURI="${DLHOST}${FILEDATA}" # dl uri

if [[ $NVERSION -gt $CVERSION ]]; then
	echo "New version available"
	echo "Current: $CURRENTVER"
	echo -e "Latest:  $NEWVER"
	echo "Downloading latest version..."
	cd "$DOWNLOADDIR"
	wget -N "$DLURI" || error "Downloading $DLURI"
	ask "Install now?" && cygstart "$FILENAME"
	exit 0
else
	echo "Already latest version: $CURRENTVER"
	exit 0
fi