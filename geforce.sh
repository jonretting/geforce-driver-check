#!/bin/bash
# git@git.lowjax.com:user/geforce-driver-check.git
# Script for checking for newer Nvidia Display Driver than the one install (x64 win7-win8)
VERSION="0.04"

# cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror

# binary dependency array
DEPS=('PnPutil' 'wget' 'awk' 'cut' 'head' 'sed' 'wc' 'find' '7z' 'cygpath' 'ln' 'which')

# clear vars *no edit

LINK=
FILEDATA=
FILENAME=
LATESTVER=
REMOEMS=
OLDOEMINF=
CURRENTVER=
DLURI=
SILENT=false
YES=false
CWD=$PWD
SEVENZIP=
BINPATH=
USE7ZPATH=false

# error func
error() { echo "Error: $1"; exit 1; }

# ask function
ask() {
	while true; do
		if [[ "${2:-}" = "Y" ]]; then prompt="Y/n"; default=Y
		elif [[ "${2:-}" = "N" ]]; then prompt="y/N"; default=N
		else prompt="y/n"; default=;
		fi
		if [[ "$1" = "-y" ]]; then REPLY=Y; default=Y #need debug
		else echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
		esac
	done
}

#needs cleanup/optimization/abstraction
find7z() {
	local path=$(cygpath -W | cut -d '/' -f1-3)
	if [[ -d "${path}/Program Files" ]]; then
		cd "${path}/Program Files"
		local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
		[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SEVENZIP="${PWD}/${find}/7z.exe"
		cd "$CWD"
	fi
	if [[ -z $SEVENZIP ]] && [[ -d "${path}/Program Files (x86)" ]]; then
		cd "${path}/Program Files (x86)"
		local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
		[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SEVENZIP="${PWD}/${find}/7z.exe"
		cd "$CWD"
	fi
	[[ -z $SEVENZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		[[ -d "$BINPATH" ]] && ln -s "$SEVENZIP" "$BINPATH"
	fi
	return 0
}

usage() {
	echo "Geforce Driver Check
Desc: Cleans unused/old inf packages, checks for new version, and installs new version)
Usage: geforce.sh [-s] [-y]
Example: geforce.sh
-s    Silent install (install new version without the Nvidia GUI)
-y    Answer 'yes' to all prompts
-V    Displays version info
-h    this crupt
Version: ${VERSION}"
}

while getopts syhV OPTIONS; do
	case "${OPTIONS}" in
		s) SILENT=true	;;
		y) YES=true	;;
		V) usage | tail -n 1; exit 0	;;
		h) usage; exit 0	;;
		*) usage; exit 1	;;
	esac
done
shift $(($OPTIND -1))

# check binary dependencies
for i in "${DEPS[@]}"; do
	#7zip check and create symlink
	if [[ $i == '7z' ]]; then
		hash $i 2>/dev/null || find7z && hash $i 2>/dev/null || USE7ZPATH=true
	else
		hash $i 2>/dev/null || error "Dependency not found :: $i"
	fi
done

# check if DOWNLOADDIR exists
[[ -d "$DOWNLOADDIR" ]] || error "Directory not found \"$DOWNLOADDIR\""

# remove unused oem*.inf packages and set OLDOEMINF from in use
REMOEMS=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/Published/ {print $4}')
if [[ $(echo "$REMOEMS" | wc -l) -gt 1 ]]; then
	for REOEM in $REMOEMS; do
		[[ $REOEM == oem*.inf ]] || error "removing in unused oem*.inf file :: $REOEM"
		PnPutil -d $REOEM >/dev/null || OLDOEMINF="$REOEM"
	done
fi

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
CURRENTVER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENTVER =~ ^[0-9]+$ ]] || error "CURRENTVER not a number or multistring :: $CURRENTVER"

# old oem*.inf file if not already detected
[[ -z $OLDOEMINF ]] && OLDOEMINF=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | grep -B 3 "$(echo "$CURRENTVER" | sed 's/./.&/2')" | awk '/Published/ {print $4}')
[[ $OLDOEMINF == oem*.inf ]] || error "Old oem*.inf file :: $OLDOEMINF"

# store full uri
DLURI="${DLHOST}${FILEDATA}"

#check versions
[[ $LATESTVER -le $CURRENTVER ]] && { echo "Already latest version: $(echo $CURRENTVER| sed 's/./.&/4')"; exit 0; }

#run tasks
echo -e "New version available!
Current: $(echo $CURRENTVER | sed 's/./.&/4')
Latest:  $(echo $LATESTVER | sed 's/./.&/4')
Downloading latest version into \"$DOWNLOADDIR\"...."
cd "$DOWNLOADDIR" || error "Changing to download directory \"$DOWNLOADDIR\""
wget -N "$DLURI" || error "Downloading file \"$DLURI\""
ask "Install new version ($LATESTVER) now?" &&
cygstart -w "$FILENAME" || error "Installation failed or user interupted!"
echo -ne "Removing old driver package..."
PnPutil -d $OLDOEMINF >/dev/null || error "Removing old oem*.inf package (maybe in use):: $OLDOEMINF"
echo "Done"
echo "Driver installation successfull!"

exit 0