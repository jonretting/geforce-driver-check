#!/bin/bash
# git@git.lowjax.com:user/geforce-driver-check.git
# Script for checking for newer Nvidia Display Driver than the one install (x64 win7-win8)

# cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror

# binary dependency array
DEPS=('PnPutil' 'wget' 'awk' 'cut' 'head' 'sed')

# clear vars *no edit
LINK=
FILEDATA=
FILENAME=
LATESTVER=
CURRENTVER=
DLURI=

# error func
error() { echo "Error: $1"; exit 1; }

# ask function
ask() {
	while true; do
		if [[ "${2:-}" = "Y" ]]; then prompt="Y/n"; default=Y
		elif [[ "${2:-}" = "N" ]]; then prompt="y/N"; default=N
		else prompt="y/n"; default=;
		fi
		if [[ "$1" = "-y" ]]; then REPLY=Y; default=Y
		else echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
		esac
	done
}

# check binary dependencies
for i in "${DEPS[@]}"; do
	hash $i 2>/dev/null || error "Dependency not found :: $i"
done

# check if DOWNLOADDIR exists
[[ -d "$DOWNLOADDIR" ]] || error "Directory not found \"$DOWNLOADDIR\""

# default nvidia starting link
LINK="http://www.nvidia.com/Download/processFind.aspx?psid=95&pfid=695&osid=19&lid=1&whql=&lang=en-us"

# file data query
FILEDATA=$(wget -qO- "$(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1)" | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
[[ $FILEDATA == *.exe ]] || error "Unexpected FILEDATA returned :: $FILEDATA"

# store file name only
FILENAME=$(echo "$FILEDATA" | cut -d '/' -f4)
[[ $FILENAME == *.exe ]] || error "Unexpected FILENAME returned :: $FILENAME"

# store latest version
LATESTVER=$(echo "$FILEDATA" | cut -d '/' -f3 | sed -e "s/\.//")
[[ $LATESTVER =~ ^[0-9]+$ ]] || error "LATESTVER not a number :: $LATESTVER"

# store current version
CURRENTVER=$(PnPutil.exe -e | grep -A 3 "NVIDIA" | grep -A 1 "Display" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENTVER =~ ^[0-9]+$ ]] || error "CURRENTVER not a number :: $CURRENTVER"

# store full uri
DLURI="${DLHOST}${FILEDATA}"

if [[ $LATESTVER -gt $CURRENTVER ]]; then
	echo "New version available!"
	echo "Current: $CURRENTVER"
	echo -e "Latest:  $LATESTVER"
	echo "Downloading latest version into \"$DOWNLOADDIR\"...."
	cd "$DOWNLOADDIR" || error "Changing to download directory \"$DOWNLOADDIR\""
	wget -N "$DLURI" || error "Downloading file \"$DLURI\""
	ask "Install new version ($LATESTVER) now?" && cygstart "$FILENAME"
	exit 0
else
	echo "Already latest version: $CURRENTVER"
	exit 0
fi