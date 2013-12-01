#!/usr/bin/env bash
# Checks for newer Nvidia Display Driver then installs silently or with many more options

# Copyright (c) 2013 Jon Retting
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

VERSION="1.026"

# cutomizable defaults
DOWNLOAD_DIR="/cygdrive/e/Downloads" #download driver file into this directory
DL_HOST="http://us.download.nvidia.com" #use this download mirror
ROOT_PATH="/cygdrive/c" #$(cygpath -W | sed -e "s/\/Windows//")

# default vars
LINK="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us"
DESKTOP_ID="&psid=95"
NOTEBOOK_ID="&psid=92"
EXCLUDE_PKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"
SETUP_ARGS="-nofinish -passive -nosplash -noeula -n" #-n noreboot
CWD=$PWD

# clear default vars
FILE_DATA=
FILE_NAME=
LATEST_VER=
REM_OEMS=
OLD_OEM_INF=
CURRENT_VER=
DLURI=
SEVEN_ZIP=
EXTRACT_SUB_DIR=
LATEST_VER_NAME= #adds decimal
CURRENT_VER_NAME= #adds decimal
GDC_PATH=
CYG_USER=
WIN_USER=
DEFAULT_DOWN_DIR=

# default flags
SILENT=false
YES=false
USE_7Z_PATH=false
CHECK_ONLY=false
ATTENDED=false
CLEAN_INSTALL=false
NOTEBOOK=false

# binary dependency array
DEPS=('PnPutil' 'wget' '7z' 'cygpath' 'wmic')

error() { echo -e "Error: $1"; exit 1; }

ask() {
	while true; do
		if [[ "${2:-}" = "Y" ]]; then prompt="Y/n"; default=Y
		elif [[ "${2:-}" = "N" ]]; then prompt="y/N"; default=N
		else prompt="y/n"; default=;
		fi
		if $YES; then REPLY=Y; default=Y
		else echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
		esac
	done
}

checkdir() {
	[[ -d "$1" ]] && return 0 || return 1
}

checkfile() {
	[[ -e "$1" ]] && return 0 || return 1
}

# cleanup
find7z() {
	local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
	[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SEVEN_ZIP="${PWD}/${find}/7z.exe"
	cd "$CWD"
}

# cleanup
7zip() {
	checkdir "${ROOT_PATH}/Program Files" &&	cd "${ROOT_PATH}/Program Files" && find7z
	[[ -z $SEVEN_ZIP ]] && checkdir "${ROOT_PATH}/Program Files (x86)" &&	cd "${ROOT_PATH}/Program Files (x86)" &&	find7z
	[[ -z $SEVEN_ZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		checkdir "$BINPATH" && ln -s "$SEVEN_ZIP" "$BINPATH"
	else
		USE_7Z_PATH=true
	fi
}

usage() {
	echo "Geforce Driver Check
Desc: Cleans unused/old inf packages, checks for new version, and installs new version)
Usage: geforce.sh [-s] [-y]
Example: geforce.sh
-a    Attended install (user must traverse Nvidia setup GUI)
-s    Silent install (dont show Nvidia progress bar)
-y    Answer 'yes' to all prompts
-c    Clean install (removes all saved profiles and settings)
-d    Specify download location
-C    Only check for new version (returns version#, 0=update available, 1=no update)
-A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
-V    Displays version info
-h    this crupt
Version: ${VERSION}"
}

while getopts asyhVcCAd: OPTIONS; do
	case "${OPTIONS}" in
		a) ATTENDED=true	;;
		s) SILENT=true		;;
		y) YES=true			;;
		d) DOWNLOAD_DIR="$OPTARG"	;;
		c) CLEAN_INSTALL=true	;;
		V) usage | tail -n 1; exit 0	;;
		C) CHECK_ONLY=true	;;
		A) ATTENDED=true; EXCLUDE_PKGS=	;;
		h) usage; exit 0	;;
		*) usage; exit 1	;;
	esac
done
shift $(($OPTIND -1))

# check binary dependencies
for i in "${DEPS[@]}"; do
	#7zip check|find and create symlink
	if [[ $i == '7z' ]]; then
		hash $i 2>/dev/null || 7zip
	else
		hash $i 2>/dev/null || error "Dependency not found :: $i"
	fi
done

# get check usernames
CYG_USER=$(echo "${HOME}" | cut -d '/' -f3)
[[ -n "$CYG_USER" ]] || error "retrieving cygwin session username"
WIN_USER=$(wmic computersystem get username | sed -n 2p | awk '{print $1}' | cut -d '\' -f2)
[[ -n "$WIN_USER" ]] || error "retrieving Windows session username"

# check set default download directory
DEFAULT_DOWN_DIR="${ROOT_PATH}/Users/${WIN_USER}/Downloads"
checkdir "$DOWNLOAD_DIR" || DOWNLOAD_DIR="$DEFAULT_DOWN_DIR"
checkdir "$DOWNLOAD_DIR" || error "Directory not found $DOWNLOAD_DIR try '-d' or specify $DOWNLOAD_DIR manually"

# get/check geforce-driver-check bash source
checkfile "${BASH_SOURCE}" || error "establishing script source path"
GDC_PATH=$(dirname ${BASH_SOURCE})
checkdir "$GDC_PATH" || error "establishing script source directory"

# check for notebook adapater
VID_DESC=$(wmic PATH Win32_VideoController GET Description | grep "NVIDIA")
checkfile "${GDC_PATH}/devices_notebook.txt" || error "checking devices_notebook.txt"
[[ -n "$VID_DESC" ]] && cat "${GDC_PATH}/devices_notebook.txt" | grep -qs "$VID_DESC" && NOTEBOOK=true

# remove unused oem*.inf packages and set OLD_OEM_INF from in use
REM_OEMS=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/Published/ {print $4}')
if [[ $(echo "$REM_OEMS" | wc -l) -gt 1 ]]; then
	for REOEM in $REM_OEMS; do
		[[ $REOEM == oem*.inf ]] || error "Unexpected value in REOEMS array :: $REOEM"
		PnPutil -d $REOEM >/dev/null || OLD_OEM_INF="$REOEM"
	done
fi

# file data query
$NOTEBOOK && LINK+="$NOTEBOOK_ID" || LINK+="$DESKTOP_ID"
FILE_DATA=$(wget -qO- $(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1) | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
[[ $FILE_DATA == *.exe ]] || error "Unexpected FILE_DATA returned :: $FILE_DATA"

# get file name only
FILE_NAME=$(echo "$FILE_DATA" | cut -d '/' -f4)
[[ $FILE_NAME == *.exe ]] || error "Unexpected FILE_NAME returned :: $FILE_NAME"

# get latest version
LATEST_VER=$(echo "$FILE_DATA" | cut -d '/' -f3 | sed -e "s/\.//")
[[ $LATEST_VER =~ ^[0-9]+$ ]] || error "LATEST_VER not a number :: $LATEST_VER"
LATEST_VER_NAME=$(echo $LATEST_VER| sed 's/./.&/4')

# get current version
CURRENT_VER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENT_VER =~ ^[0-9]+$ ]] || error "CURRENT_VER not a number :: $CURRENT_VER"
CURRENT_VER_NAME=$(echo $CURRENT_VER | sed 's/./.&/4')

# old oem*.inf file if not already detected
[[ -z $OLD_OEM_INF ]] && OLD_OEM_INF=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | grep -B 3 "$(echo "$CURRENT_VER" | sed 's/./.&/2')" | awk '/Published/ {print $4}')
[[ $OLD_OEM_INF == oem*.inf ]] || error "Old oem*.inf file :: $OLD_OEM_INF"

# store full uri
DLURI="${DL_HOST}${FILE_DATA}"

# check versions
if [[ $CURRENT_VER -eq $LATEST_VER ]]; then
	$CHECK_ONLY && exit 1
	echo "Already latest version: $CURRENT_VER_NAME"
	exit 0
fi
$CHECK_ONLY && { echo "$CURRENT_VER_NAME --> $LATEST_VER_NAME"; exit 0; }

# run tasks
echo -e "New version available!
Current: $CURRENT_VER_NAME
Latest:  $LATEST_VER_NAME
Downloading latest version into \"$DOWNLOAD_DIR\"..."
cd "$DOWNLOAD_DIR" || error "Changing to download directory \"$DOWNLOAD_DIR\""
wget -N "$DLURI" || error "wget downloading file \"$DLURI\""

# ask to isntall
ask "Extract and Install new version ($LATEST_VER_NAME) now?" || { echo "User cancelled"; exit 0; }

# unarchive new version download
checkdir "${ROOT_PATH}/NVIDIA" || mkdir "${ROOT_PATH}/NVIDIA" || error "creating directory :: \"$ROOT_PATH/NVIDIA\""
EXTRACT_SUB_DIR="${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}"
echo -ne "Extracting new driver archive..."
checkdir "$EXTRACT_SUB_DIR" && rm -rf "$EXTRACT_SUB_DIR"
7z x "$(cygpath -wap "${DOWNLOAD_DIR}/${FILE_NAME}")" -o"$(cygpath -wap "${EXTRACT_SUB_DIR}")" $EXCLUDE_PKGS >/dev/null || error "extracting new download"
echo "Done"

# create setup.exe options args
$SILENT && SETUP_ARGS+=" -s"
$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
$ATTENDED && SETUP_ARGS=

# run the installer with args
echo -ne "Executing installer setup..."
cygstart -w "$EXTRACT_SUB_DIR/setup.exe" "$SETUP_ARGS" || error "Installation failed or user interupted"
echo "Done"

# remove old oem inf package
echo -ne "Removing old driver package..."
PnPutil -d $OLD_OEM_INF >/dev/null || error "Removing old oem*.inf package (maybe in use):: $OLD_OEM_INF"
echo "Done"

# final check verify new version
CURRENT_VER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENT_VER -eq $LATEST_VER ]] || error "After all that your driver version didn't change!"
echo "Driver update successfull!"

exit 0