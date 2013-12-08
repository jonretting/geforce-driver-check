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
DOWNLOAD_PATH=$(cygpath "${HOMEDRIVE}${HOMEPATH}/Downloads") #download driver file into this path
DOWNLOAD_MIRROR="http://us.download.nvidia.com" #use this download mirror
INTERNATIONAL=false		# true use international driver package version multi language support
NOTEBOOK=false			# true use notebook driver version, skip check adapter type

# default vars
ROOT_PATH=$(cygpath "$SYSTEMDRIVE")
MSIEXEC_PATH="${ROOT_PATH}/Windows/msiexec"
CWD="$PWD"
LINK="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
DESKTOP_ID="95"
NOTEBOOK_ID="92"
EXCLUDE_PKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"
SETUP_ARGS="-nofinish -passive -nosplash -noeula"
SZIP_DOWNLOAD_URI="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
GDC_PATH=$(dirname ${BASH_SOURCE})
CYG_USER=$(whoami)
WIN_USER="$USERNAME"
OS_VERSION=$(uname -s)
ARCH_TYPE=$(uname -m)

# default flags (change if you know what you are doing)
SILENT=false
YES_TO_ALL=false
USE_7Z_PATH=false
CHECK_ONLY=false
ATTENDED=false
CLEAN_INSTALL=false
ENABLE_REBOOT_PROMPT=false
DEBUG=false
UPDATE=false

# clear default vars (do not edit)
FILE_DATA=
FILE_NAME=
LATEST_VER=
INSTALLED_VER=
DOWNLOAD_URI=
SEVEN_ZIP=
LATEST_VER_NAME=
INSTALLED_VER_NAME=
DOWNLOAD_URI=


# binary dependency array
DEPS=('wget' '7z')

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

check-hash() {
	hash "$1" 2>/dev/null || return 1
	return 0
}

check-path() {
	[[ -d "$1" ]] && [[ -r "$1" ]] || return 1 
	return 0
}

check-file() {
	[[ -e "$1" ]] && [[ -r "$1" ]] || return 1
	return 0
}

check-mkdir () {
	check-path "$1" || mkdir || return 1
	return 0
}

7zip() {
	7z-find || 7z-find " (x86)" || 7z-dli || return 1
	[[ -z $SEVEN_ZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		check-path "$BINPATH" && ln -s "$SEVEN_ZIP" "$BINPATH" || error "creating 7z symbolic link"
		return 0
	else
		USE_7Z_PATH=true
		return 0
	fi
}
# error "validating folder :: ${ROOT_PATH}/Program Files$1"

7z-find() {
	check-path "${ROOT_PATH}/Program Files${1}" || return 1
	local FIND=$(find "${ROOT_PATH}/Program Files${1}" -maxdepth 2 -type f -name "7z.exe" -print)
	for i in "$FIND"; do
		[[ -x "${i}" ]] && { SEVEN_ZIP="${i}"; return 0; }
	done
	return 1
}

7z-dli () {
	if ask "Download 7-Zip v9.22 x86_64 msi package?"; then
		wget -N "$SZIP_DOWNLOAD_URI" || error "downloading 7-Zip msi package :: $SZIP_DOWNLOAD_URI"
		[[ -e "$MSIEXEC_PATH" ]] || error "msiexec.exe not found :: $MSIEXEC_PATH"
		[[ -x "$MSIEXEC_PATH" ]] || error "msiexec not executable :: $MSIEXEC_PATH"
		if ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2"; then
			"${ROOT_PATH}/Windows/System32/msiexec.exe" /passive /norestart /i $(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi") || error "installing 7-Zip, or user cancelled"
		else
			cygstart -w "${ROOT_PATH}/Windows/System32/msiexec.exe" /norestart /i $(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi") || error "installing 7-Zip, or user cancelled"
		fi
		7z-find || 7z-find " (x86)"
	else
		error "User cancelled 7-Zip download"
	fi
}

wget-dli() {
	if hash apt-cyg 2>/dev/null; then
		ask "apt-cyg found, use to install wget?" && apt-cyg install wget || error "installing wget using apt-cyg, try manuall install with CYGWIN setup.exe"
		hash apt-cyg 2>/dev/null || error "something went wrong wget still not viable"
		return 0
	else
		echo "Could not autoinstall wget, please use CYGWIN setup.exe to install"
		return 1
	fi
}

check-os-ver() {
	[[ "$OS_VERSION" == CYGWIN_NT-6* ]] || return 1
	return 0
}

check-arch-type() {
	[[ "$ARCH_TYPE" == "x86_64" ]] || return 1
	return 0
}

check-usernames() {
	[[ -n "$CYG_USER" && -n "$WIN_USER" ]] || return 1
	return 0
}

dev-archive() {
	gzip -dfc "${GDC_PATH}/devices_notebook.txt.gz" > "${GDC_PATH}/devices_notebook.txt" || return 1
	check-file "${GDC_PATH}/devices_notebook.txt" || return 1
	return 0
}

get-online-data() {
	$NOTEBOOK && LINK+="$NOTEBOOK_ID" || LINK+="$DESKTOP_ID"
	FILE_DATA=$(wget -qO- 2>/dev/null $(wget -qO- 2>/dev/null "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1) | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
	[[ $FILE_DATA == *.exe ]] || return 1
	return 0
}

get-latest-name() {
	FILE_NAME=$(echo "$FILE_DATA" | cut -d '/' -f4)
	[[ $FILE_NAME == *.exe ]] || return 1
	return 0
}

get-latest-ver() {
	LATEST_VER=$(echo "$FILE_DATA" | cut -d '/' -f3 | sed -e "s/\.//")
	LATEST_VER_NAME=$(echo $LATEST_VER| sed "s/./.&/4")
	[[ $LATEST_VER =~ ^[0-9]+$ ]] || return 1
	return 0
}

get-installed-ver() {
	INSTALLED_VER=$(wmic PATH Win32_VideoController GET DriverVersion | grep -Eo '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,4}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')
	INSTALLED_VER_NAME=$(echo $INSTALLED_VER | sed "s/./.&/4")
	[[ $INSTALLED_VER =~ ^[0-9]+$ ]] || return 1
	return 0
}

is-notebook() {
	VID_DESC=$(wmic PATH Win32_VideoController GET Description | grep "NVIDIA")
	[[ -n "$VID_DESC" ]] && cat "${GDC_PATH}/devices_notebook.txt" | grep -qs "$VID_DESC" || return 1
	return 0
}

check-uri() {
	wget -t 1 -T 3 -q --spider "$1" || return 1
	return 0
}

create-driver-uri() {
	DOWNLOAD_URI="${DOWNLOAD_MIRROR}${FILE_DATA}"
	$INTERNATIONAL && DOWNLOAD_URI=$(echo $DOWNLOAD_URI | sed -e "s/english/international/")
	check-uri "$DOWNLOAD_URI" || return 1
	return 0
}

check-versions() {
	$DEBUG && INSTALLED_VER="33090"
	[[ $INSTALLED_VER -ge $LATEST_VER ]] && return 1
	return 0
}

update-txt() {
	$1 || echo -e "Already latest version: $INSTALLED_VER_NAME"
	$1 && echo -e "New version available!\nCurrent: $INSTALLED_VER_NAME\nLatest:  $LATEST_VER_NAME"
	return 0
}

ask-prompt-setup() {
	ask "Download, Extract, and Install new version ( ${LATEST_VER_NAME} ) now?" || {
		echo "User cancelled"; return 1; }
	return 0
}

download-driver() {
	echo -e "Downloading latest version into \"${DOWNLOAD_PATH}\"..."
	wget -N -P "$DOWNLOAD_PATH" "$DOWNLOAD_URI" || return 1
	return 0
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
	return 0
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

check-os-ver || error "Unsupported OS Version :: $OS_VERSION"
check-arch-type || error "Unsupported architecture :: $ARCH_TYPE"
check-usernames || error "validating session usernames :: $WIN_USER / $CYG_USER"
check-path "$ROOT_PATH" || error "validating root path :: $ROOT_PATH"
check-path "$DOWNLOAD_PATH" || error "validating download path :: $DOWNLOAD_PATH"
check-path "$GDC_PATH" || error "validating script source path :: $GDC_PATH"

# check binary dependencies
for i in "${DEPS[@]}"; do
	case "$i" in
		7z) 
			check-hash 7z || 7zip || error "Dependency not found :: $i"	
		;;
		wget)
			check-hash wget || wget-dli || error "Dependency not found :: $i"
		;;
		*)
			check-hash "$i" || error "Dependency not found :: $i"
		;;
	esac
done

 "${ROOT_PATH}/NVIDIA" || mkdir "${ROOT_PATH}/NVIDIA" || error "creating path :: \"$ROOT_PATH/NVIDIA\""

dev-archive || error "validating devices dbase :: ${GDC_PATH}/devices_notebook.txt"
is-notebook && NOTEBOOK=true
get-online-data || error "in online data query :: $FILE_DATA"
get-latest-name || error "invalid file name returned :: $FILE_NAME"
get-latest-ver || error "invalid driver version string :: $LATEST_VER"
get-installed-ver || error "invalid driver version string :: $INSTALLED_VER"
create-driver-uri || error "validating driver download uri :: $DOWNLOAD_URI"
check-versions && UPDATE=true
$UPDATE || update-txt false
$UPDATE && update-txt true
$UPDATE && $CHECK_ONLY && exit 1
$UPDATE && ask-prompt-setup || exit 1
download-driver || error "wget downloading file :: $DOWNLOAD_URI"
check-mkdir "${ROOT_PATH}/NVIDIA" || error "creating path :: ${ROOT_PATH}/NVIDIA"

echo -ne "Extracting new driver archive..."
check-path "${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}" && rm -rf "${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}"
7z x "$(cygpath -wa "${DOWNLOAD_PATH}/${FILE_NAME}")" -o"$(cygpath -wa "${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}")" $EXCLUDE_PKGS >/dev/null || error "extracting new driver archive"
echo "Done"

# create setup.exe options args
$SILENT && SETUP_ARGS+=" -s"
$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
$ATTENDED && SETUP_ARGS=
$ENABLE_REBOOT_PROMPT || SETUP_ARGS+=" -n"

# run the installer with args
echo -ne "Executing installer setup..."
if $DEBUG; then
	echo "cygstart -w ${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}/setup.exe $SETUP_ARGS"
else
	cygstart -w "${ROOT_PATH}/NVIDIA/GDC-${LATEST_VER_NAME}/setup.exe" "$SETUP_ARGS" || error "Installation failed or user interupted"
fi
echo "Done"

# final check verify new version
INSTALLED_VER=$(wmic PATH Win32_VideoController GET DriverVersion | grep -Eo '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,4}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')
[[ $INSTALLED_VER -eq $LATEST_VER ]] || error "After all that your driver version didn't change!"
echo "Driver update successfull!"

exit 0