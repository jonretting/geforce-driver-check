#!/usr/bin/env bash
# NAME: Geforce Driver Check (GDC) geforce-driver-check
# DESC: Checks for new Nvidia Display Drivers then does an automatted unattended install, or with many more options.
# REPO: git@github.com:jonretting/geforce-driver-check.git
# GITHUB: https://github.com/jonretting/geforce-driver-check/

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

VERSION="1.041"

# cutomizable defaults
DOWNLOAD_PATH="/cygdrive/e/Downloads" #download driver file into this path
DOWNLOAD_MIRROR="http://us.download.nvidia.com" #use this download mirror
ROOT_PATH="/cygdrive/c" #$(cygpath -W | sed -e "s/\/Windows//") # auto determines root path via cygpath
INTERNATIONAL=false		# true = use international driver package version multi language support
NOTEBOOK=false			# true = use notebook driver version, skip check adapter type

# default vars
LINK="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us"
DESKTOP_ID="&psid=95"
NOTEBOOK_ID="&psid=92"
EXCLUDE_PKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"
SETUP_ARGS="-nofinish -passive -nosplash -noeula"
CWD="$PWD"
SZIP_DOWNLOAD_URI="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
MSIEXEC_PATH="${ROOT_PATH}/Windows/System32/msiexec.exe"

# default flags (change if you know what you are doing)
SILENT=false
YES_TO_ALL=false
USE_7Z_PATH=false
CHECK_ONLY=false
ATTENDED=false
CLEAN_INSTALL=false
ENABLE_REBOOT_PROMPT=false
DEBUG=false

# clear default vars (do not edit)
FILE_DATA=
FILE_NAME=
LATEST_VER=
REM_OEMS=
CURRENT_OEM_INF=
CURRENT_VER=
DOWNLOAD_URI=
SEVEN_ZIP=
EXTRACT_SUB_PATH=
LATEST_VER_NAME=
CURRENT_VER_NAME=
GDC_PATH=
CYG_USER=
WIN_USER=
FALLBACK_DOWNLOAD_PATH=
DOWNLOAD_URI=
OS_VERSION=
ARCH_TYPE=
LOCAL_DRIVER_DATA=

# binary dependency array
DEPS=('PnPutil' 'wget' '7z' 'cygpath' 'wmic')

error() { echo -e "Error: $1"; exit 1; }

ask() {
	while true; do
		if $YES_TO_ALL; then 
			local REPLY=Y; local default=Y
		elif [[ "$2" ]]; then
			local prompt="$2"; local default=
		else
			local prompt="y/n"; local default=
		fi
		if [[ -z $default ]]; then
			echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && local REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
			1*) return 0 ;; 2*) return 1 ;;
		esac
	done
}

checkdir() {
	[[ -d "$1" ]] && [[ -r "$1" ]] && return 0 || return 1
}

checkfile() {
	[[ -e "$1" ]] && [[ -r "$1" ]] && return 0 || return 1
}

7zip() {
	7zfind || 7zfind " (x86)" || 7zdli || return 1
	[[ -z $SEVEN_ZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		checkdir "$BINPATH" && ln -s "$SEVEN_ZIP" "$BINPATH" || error "creating 7z symbolic link"
		return 0
	else
		USE_7Z_PATH=true
		return 0
	fi
}

7zfind() {
	checkdir "${ROOT_PATH}/Program Files${1}" || error "validating folder :: ${ROOT_PATH}/Program Files$1"
	local FIND=$(find "${ROOT_PATH}/Program Files${1}" -maxdepth 2 -type f -name "7z.exe" -print)
	for i in "$FIND"; do
		[[ -x "${i}" ]] && { SEVEN_ZIP="${i}"; return 0; }
	done
	return 1
}

7zdli () {
	if ask "Download 7-Zip v9.22 x86_64 msi package?"; then
		wget -N "$SZIP_DOWNLOAD_URI" || error "downloading 7-Zip msi package :: $SZIP_DOWNLOAD_URI"
		[[ -e "$MSIEXEC_PATH" ]] || error "msiexec.exe not found :: $MSIEXEC_PATH"
		[[ -x "$MSIEXEC_PATH" ]] || error "msiexec not executable :: $MSIEXEC_PATH"
		if ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2"; then
			"${ROOT_PATH}/Windows/System32/msiexec.exe" /passive /norestart /i $(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi") || error "installing 7-Zip, or user cancelled"
		else
			cygstart -w "${ROOT_PATH}/Windows/System32/msiexec.exe" /norestart /i $(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi") || error "installing 7-Zip, or user cancelled"
		fi
		7zfind || 7zfind " (x86)"
	else
		error "User cancelled 7-Zip download"
	fi
}

wgetdli() {
	if hash apt-cyg 2>/dev/null; then
		ask "apt-cyg found, use to install wget?" && apt-cyg install wget || error "installing wget using apt-cyg, try manuall install with CYGWIN setup.exe"
		hash apt-cyg 2>/dev/null || error "something went wrong wget still not viable"
		return 0
	else
		echo "Could not autoinstall wget, please use CYGWIN setup.exe to install"
		return 1
	fi
}

devarchive() {
	if checkfile "${GDC_PATH}/devices_notebook.txt.gz"; then
		gzip -df "${GDC_PATH}/devices_notebook.txt.gz" || error "gzip decompress devices_notebook.txt.gz"
		checkfile "${GDC_PATH}/devices_notebook.txt" || error "cannot read or missing :: ${GDC_PATH}/devices_notebook.txt"
		return 0
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
-i    Download international driver package (driver package for non English installs)
-r    Don't disable reboot prompt when reboot is needed (could be buged)
-V    Displays version info
-h    this crupt
Version: ${VERSION}"
}

while getopts asyd:cVCAirh OPTIONS; do
	case "${OPTIONS}" in
		a) ATTENDED=true	;;
		s) SILENT=true		;;
		y) YES_TO_ALL=true			;;
		d) DOWNLOAD_PATH="$OPTARG"	;;
		c) CLEAN_INSTALL=true	;;
		V) usage | tail -n 1; exit 0	;;
		C) CHECK_ONLY=true	;;
		A) ATTENDED=true; EXCLUDE_PKGS=	;;
		i) INTERNATIONAL=true	;;
		r) ENABLE_REBOOT_PROMPT=true	;;
		h) usage; exit 0	;;
		*) usage; exit 1	;;
	esac
done
shift $(($OPTIND - 1))

# check os and architecture
OS_VERSION=$(uname -s)
[[ "$OS_VERSION" == CYGWIN_NT-6* ]] || error "Unsupported OS Version :: $(uname -s)"
ARCH_TYPE=$(uname -m)
[[ "$ARCH_TYPE" == x86_64 ]] || error "Unsupported architecture :: $(uname -m)"

# set default download path
FALLBACK_DOWNLOAD_PATH="${ROOT_PATH}/Users/${WIN_USER}/Downloads"
checkdir "$DOWNLOAD_PATH" || DOWNLOAD_PATH="$FALLBACK_DOWNLOAD_PATH"
checkdir "$DOWNLOAD_PATH" || error "Path not found $DOWNLOAD_PATH"

# check binary dependencies
for i in "${DEPS[@]}"; do
	case "$i" in
		7z) hash $i 2>/dev/null || 7zip || error "Dependency not found :: $i"	;;
		wget) hash wget 2>/dev/null || wgetdli || error "Dependency not found :: $i"	;;
		*) hash $i 2>/dev/null || error "Dependency not found :: $i"	;;
	esac
done

# set usernames
CYG_USER=$(echo "${HOME}" | cut -d '/' -f3)
[[ -n "$CYG_USER" ]] || error "retrieving cygwin session username"
WIN_USER=$(wmic computersystem get username | awk -F"\\" -v RS= '{print $3}')
[[ -n "$WIN_USER" ]] || error "retrieving Windows session username"

# set geforce-driver-check script path
checkfile "${BASH_SOURCE}" || error "establishing script source path"
GDC_PATH=$(dirname ${BASH_SOURCE})
checkdir "$GDC_PATH" || error "establishing script source path"

# check for notebook adapater
VID_DESC=$(wmic PATH Win32_VideoController GET Description | grep "NVIDIA")
devarchive || error "in devices_notebook"
[[ -n "$VID_DESC" ]] && cat "${GDC_PATH}/devices_notebook.txt" | grep -qs "$VID_DESC" && NOTEBOOK=true

# online file data query
$NOTEBOOK && LINK+="$NOTEBOOK_ID" || LINK+="$DESKTOP_ID"
FILE_DATA=$(wget -qO- 2>/dev/null $(wget -qO- 2>/dev/null "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1) | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
[[ $FILE_DATA == *.exe ]] || error "Unexpected FILE_DATA returned :: $FILE_DATA"

# get file name only
FILE_NAME=$(echo "$FILE_DATA" | cut -d '/' -f4)
[[ $FILE_NAME == *.exe ]] || error "Unexpected FILE_NAME returned :: $FILE_NAME"
# get latest version
LATEST_VER=$(echo "$FILE_DATA" | cut -d '/' -f3 | sed -e "s/\.//")
[[ $LATEST_VER =~ ^[0-9]+$ ]] || error "LATEST_VER not a number :: $LATEST_VER"
LATEST_VER_NAME=$(echo $LATEST_VER| sed "s/./.&/4")

# local driver data query
LOCAL_DRIVER_DATA=$(PnPutil.exe -e | awk -v RS= -F: '/Display adapter/ && /NVIDIA/')

# get current version
CURRENT_VER=$(echo $LOCAL_DRIVER_DATA | grep -Eo '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,4}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')
[[ $CURRENT_VER =~ ^[0-9]+$ ]] || error "CURRENT_VER not a number :: $CURRENT_VER"
CURRENT_VER_NAME=$(echo $CURRENT_VER | sed "s/./.&/4")

# store full dl uri
DOWNLOAD_URI="${DOWNLOAD_MIRROR}${FILE_DATA}"
$INTERNATIONAL && DOWNLOAD_URI=$(echo $DOWNLOAD_URI | sed -e "s/english/international/")

# check versions
$DEBUG && CURRENT_VER="33090"
if [[ $CURRENT_VER -ge $LATEST_VER ]]; then
	# make notification nicer
	$CHECK_ONLY && { echo "Already latest version: $CURRENT_VER_NAME"; exit 1; }
	echo "Already latest version: $CURRENT_VER_NAME"
	exit 0
fi

# make  notification nicer
$CHECK_ONLY && { echo -e "New version available!\nCurrent: ${CURRENT_VER_NAME}\nLatest:  ${LATEST_VER_NAME}"; exit 1; }

# run tasks
echo -e "New version available!\nCurrent: $CURRENT_VER_NAME\nLatest:  $LATEST_VER_NAME"

# ask to download and install (continue)
ask "Download, Extract, and Install new version ( ${LATEST_VER_NAME} ) now?" || { echo "User cancelled"; exit 0; }

echo -e "Downloading latest version into \"${DOWNLOAD_PATH}\"..."
cd "$DOWNLOAD_PATH" || error "cd to download path :: $DOWNLOAD_PATH"
wget -N "$DOWNLOAD_URI" || error "wget downloading file :: $DOWNLOAD_URI"

# remove unused oem*.inf packages and set CURRENT_OEM_INF
REM_OEMS=$(echo $LOCAL_DRIVER_DATA | grep -Eo 'oem[0-9]+\.inf')
if [[ "${#REM_OEMS[@]}" -gt 1 ]]; then
	for REOEM in "${REM_OEMS[@]}"; do
		[[ "$REOEM" =~ ^'oem'[0-9]{1,3}'.inf'$ ]] || error "Unexpected value in REOEMS array :: $REOEM"
		PnPutil -d $REOEM >/dev/null || CURRENT_OEM_INF="$REOEM"
	done
elif [[ "${#REM_OEMS[@]}" -eq 1 ]]; then
	CURRENT_OEM_INF="$REM_OEMS"
	[[ "$CURRENT_OEM_INF" =~ ^'oem'[0-9]{1,3}'.inf'$ ]] || error "Unexpected value in CURRENT_OEM_INF array :: $CURRENT_OEM_INF"
else
	error "Could not get proper CURRENT_OEM_INF value"
fi

# unarchive new version download
checkdir "${ROOT_PATH}/NVIDIA" || mkdir "${ROOT_PATH}/NVIDIA" || error "creating path :: \"$ROOT_PATH/NVIDIA\""
EXTRACT_SUB_PATH="${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}"
echo -ne "Extracting new driver archive..."
checkdir "$EXTRACT_SUB_PATH" && rm -rf "$EXTRACT_SUB_PATH"
7z x "$(cygpath -wa "${DOWNLOAD_PATH}/${FILE_NAME}")" -o"$(cygpath -wa "${EXTRACT_SUB_PATH}")" $EXCLUDE_PKGS >/dev/null || error "extracting new driver archive"
echo "Done"

# create setup.exe options args
$SILENT && SETUP_ARGS+=" -s"
$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
$ATTENDED && SETUP_ARGS=
$ENABLE_REBOOT_PROMPT || SETUP_ARGS+=" -n"

# run the installer with args
echo -ne "Executing installer setup..."
if $DEBUG; then
	echo "cygstart -w $EXTRACT_SUB_PATH/setup.exe $SETUP_ARGS"
else
	cygstart -w "$EXTRACT_SUB_PATH/setup.exe" "$SETUP_ARGS" || error "Installation failed or user interupted"
fi
echo "Done"

# remove old oem inf package
echo -ne "Removing old driver package..."
if $DEBUG; then
	echo "PnPutil -d $CURRENT_OEM_INF >/dev/null"
else
	PnPutil -d $CURRENT_OEM_INF >/dev/null || echo -e "Error Removing old oem*.inf package (maybe in use, system might require reboot)"
fi
echo "Done"

# final check verify new version
CURRENT_VER=$(PnPutil.exe -e | awk -v RS= -F: '/Display adapter/ && /NVIDIA/' | grep -Eo '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,4}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')
[[ $CURRENT_VER -eq $LATEST_VER ]] || error "After all that your driver version didn't change!"
echo "Driver update successfull!"

exit 0