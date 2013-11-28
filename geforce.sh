#!/bin/bash
# git@git.lowjax.com:user/geforce-driver-check.git
# Script for checking for newer Nvidia Display Driver than the one install (x64 win7-win8)
VERSION="0.08"

# cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror

# default vars
LINK="http://www.nvidia.com/Download/processFind.aspx?psid=95&pfid=695&osid=19&lid=1&whql=&lang=en-us"
EXCLUDEPKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay"
SETUPARGS="-nosplash -noeula -n"
ROOTPATH="/cygdrive/c"	#$(cygpath -W | sed -e "s/\/Windows//")
CWD=$PWD

# clear default vars
FILEDATA=
FILENAME=
LATESTVER=
REMOEMS=
OLDOEMINF=
CURRENTVER=
DLURI=
SEVENZIP=
BINPATH=
EXTRACTSUBDIR=
LATESTVERNAME= #adds decimal
CURRENTVERNAME= #adds decimal

# default flags
SILENT=false
YES=false
USE7ZPATH=false
CHECKONLY=false

# binary dependency array
DEPS=('PnPutil' 'wget' 'awk' 'cut' 'head' 'tail' 'sed' 'wc' 'find' '7z' 'cygpath' 'ln' 'which')

error() { echo "Error: $1"; exit 1; }

ask() {
	while true; do
		if [[ "${2:-}" = "Y" ]]; then prompt="Y/n"; default=Y
		elif [[ "${2:-}" = "N" ]]; then prompt="y/N"; default=N
		else prompt="y/n"; default=;
		fi
		if $YES; then REPLY=Y; default=Y #need debug
		else echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
		esac
	done
}

#needs cleanup/optimization/abstraction
find7z() {
	if [[ -d "${ROOTPATH}/Program Files" ]]; then
		cd "${ROOTPATH}/Program Files"
		local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
		[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SEVENZIP="${PWD}/${find}/7z.exe"
		cd "$CWD"
	fi
	if [[ -z $SEVENZIP ]] && [[ -d "${ROOTPATH}/Program Files (x86)" ]]; then
		cd "${ROOTPATH}/Program Files (x86)"
		local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
		[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SEVENZIP="${PWD}/${find}/7z.exe"
		cd "$CWD"
	fi
	[[ -z $SEVENZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		[[ -d "$BINPATH" ]] && ln -s "$SEVENZIP" "$BINPATH"
	else
		USE7ZPATH=true
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
-C    Only check for new version (returns version#, 0=update available, 1=no update)
-V    Displays version info
-h    this crupt
Version: ${VERSION}"
}

while getopts syhVC OPTIONS; do
	case "${OPTIONS}" in
		s) SILENT=true	;;
		y) YES=true	;;
		V) usage | tail -n 1; exit 0	;;
		C) CHECKONLY=true	;;
		h) usage; exit 0	;;
		*) usage; exit 1	;;
	esac
done
shift $(($OPTIND -1))

# check binary dependencies
for i in "${DEPS[@]}"; do
	#7zip check and create symlink
	if [[ $i == '7z' ]]; then
		hash $i 2>/dev/null || find7z
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

# file data query
FILEDATA=$(wget -qO- "$(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1)" | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
[[ $FILEDATA == *.exe ]] || error "Unexpected FILEDATA returned :: $FILEDATA"

# get file name only
FILENAME=$(echo "$FILEDATA" | cut -d '/' -f4)
[[ $FILENAME == *.exe ]] || error "Unexpected FILENAME returned :: $FILENAME"

# get latest version
LATESTVER=$(echo "$FILEDATA" | cut -d '/' -f3 | sed -e "s/\.//")
[[ $LATESTVER =~ ^[0-9]+$ ]] || error "LATESTVER not a number :: $LATESTVER"
LATESTVERNAME=$(echo $LATESTVER| sed 's/./.&/4')

# get current version
CURRENTVER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENTVER =~ ^[0-9]+$ ]] || error "CURRENTVER not a number or multistring :: $CURRENTVER"
CURRENTVERNAME=$(echo $CURRENTVER | sed 's/./.&/4')

# old oem*.inf file if not already detected
[[ -z $OLDOEMINF ]] && OLDOEMINF=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | grep -B 3 "$(echo "$CURRENTVER" | sed 's/./.&/2')" | awk '/Published/ {print $4}')
[[ $OLDOEMINF == oem*.inf ]] || error "Old oem*.inf file :: $OLDOEMINF"

# store full uri
DLURI="${DLHOST}${FILEDATA}"

# check versions
if [[ $LATESTVER -lt $CURRENTVER ]]; then
	$CHECKONLY && exit 1
	echo "Already latest version: $CURRENTVERNAME"
	exit 0
fi
$CHECKONLY && { echo "$CURRENTVERNAME --> $LATESTVERNAME"; exit 0; }

# run tasks
echo -e "New version available!
Current: $CURRENTVERNAME
Latest:  $LATESTVERNAME
Downloading latest version into \"$DOWNLOADDIR\"...."
cd "$DOWNLOADDIR" || error "Changing to download directory \"$DOWNLOADDIR\""
wget -N "$DLURI" || error "Downloading file \"$DLURI\""

# ask to isntall
ask "Extract and Install new version ($LATESTVER) now?" || { echo "User cancelled"; exit 0; }

# unarchive new version download
[[ -d "${ROOTPATH}/NVIDIA" ]] || mkdir "${ROOTPATH}/MVIDIA" || error "creating directory :: \"$ROOTPATH/MVIDIA\""
EXTRACTSUBDIR="${ROOTPATH}/NVIDIA/GDC-${LATESTVERNAME}"
echo -ne "Extracting new driver archive..."
[[ -d "$EXTRACTSUBDIR" ]] && rm -rf "$EXTRACTSUBDIR"
7z x "$(cygpath -wap "${DOWNLOADDIR}/${FILENAME}")" -o"$(cygpath -wap "${EXTRACTSUBDIR}")" $EXCLUDEPKGS >/dev/null || error "extracting new download"
echo "Done"

# create setup.exe options args
$SILENT && SETUPARGS+=" -s"

# run the installer with args
echo -ne "Executing installer setup..."
cygstart -w "$EXTRACTSUBDIR/setup.exe" $SETUPARGS || error "Installation failed or user interupted!"
echo "Done"

# remove old oem inf package
echo -ne "Removing old driver package..."
PnPutil -d $OLDOEMINF >/dev/null || error "Removing old oem*.inf package (maybe in use):: $OLDOEMINF"
echo "Done"

echo "Driver installation successfull!"
exit 0