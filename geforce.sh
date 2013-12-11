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
VERSION="1.045"

# cutomizable defaults
DOWNLOAD_PATH=$(cygpath "${HOMEDRIVE}${HOMEPATH}/Downloads") # download driver file into this path use UNIX path
EXTRACT_PREFIX="${SYSTEMDRIVE}\NVIDIA" # extract driver file here use WIN/DOS path
INTERNATIONAL=false		# true use international driver package version multi language support

# default vars
ROOT_PATH=$(cygpath "$SYSTEMDRIVE")
EXCLUDE_PKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"

# default flags (change if you know what you are doing)
SILENT=false
YES_TO_ALL=false
CHECK_ONLY=false
ATTENDED=false
CLEAN_INSTALL=false
ENABLE_REBOOT_PROMPT=false

# begin functions
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
ask() {
	while true;do
		[ "$2" ] && { local pmt="$2";local def=; }; [ "$2" ] || { local pmt="y/n";local def=; }
		$YES_TO_ALL && { local RPY=Y;local def=Y; }; [ -z "$def" ] && { echo -ne "$1 ";read -p "[$pmt] " RPY; }
		[ -z "$RPY" ] && local RPY=$def; case "$RPY" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
	done
}
error() {
	echo -e "Error: geforce.sh : $1" | tee -a /var/log/messages
	exit 1
}
check-hash() {
	hash "$1" 2>/dev/null
}
check-file() {
	while [[ ${#} -gt 0 ]]; do
		case $1 in
			x) [[ -x "$2" ]] || return 1 ;;
			r) [[ -r "$2" ]] || return 1 ;;
			s) [[ -s "$2" ]] || return 1 ;;
		   rs) [[ -r "$2" && -s "$2" ]] || return 1 ;; #file read > 0
			h) [[ -h "$2" ]] || return 1 ;;
		   dr) [[ -d "$2" && -r "$2" ]] || return 1 ;; #path read
		    *) [[ -e "$1" ]] || return 1 ;;
		esac
		shift
	done
}
check-path() {
	check-file dr "$1"
}
check-mkdir () {
	check-path "$1" || mkdir "$1"
}
check-os-ver() {
	local OS_VERSION=$(uname -s)
	[[ "$OS_VERSION" == CYGWIN_NT-6* ]]
}
check-arch-type() {
	local ARCH_TYPE=$(uname -m)
	[[ "$ARCH_TYPE" == "x86_64" ]]
}
check-usernames() {
	local CYG_USER=$(whoami)
	local WIN_USER="$USERNAME"
	[[ -n "$CYG_USER" && -n "$WIN_USER" ]]
}
dev-archive() {
	gzip -dfc "${GDC_PATH}/devices_notebook.txt.gz" > "${GDC_PATH}/devices_notebook.txt" || return 1
	check-file rs "${GDC_PATH}/devices_notebook.txt"
}
get-gdc-path() {
	GDC_PATH=
	local SOURCE="${BASH_SOURCE[0]}"
	while [[ -h "$SOURCE" ]]; do
		local DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
		local SOURCE="$(readlink "$SOURCE")"
		[[ $SOURCE != /* ]] && local SOURCE="$DIR/$SOURCE"
	done
	GDC_PATH="$(cd -P "$(dirname "$SOURCE")" && pwd)"
	[[ -x "${GDC_PATH}/geforce.sh" ]]
}
get-online-data() {
	FILE_DATA=
	local DESKTOP_ID="95"
	local NOTEBOOK_ID="92"
	local LINK="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
	$NOTEBOOK && local LINK+="$NOTEBOOK_ID" || local LINK+="$DESKTOP_ID"
	# needs refactor main web query
	FILE_DATA=$(wget -qO- 2>/dev/null $(wget -qO- 2>/dev/null "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1) | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
	[[ $FILE_DATA == *.exe ]]
}
get-latest-name() {
	FILE_NAME=
	FILE_NAME=$(echo "$FILE_DATA" | cut -d '/' -f4)
	[[ $FILE_NAME == *.exe ]]
}
get-latest-ver() {
	LATEST_VER=$(echo "$FILE_DATA" | cut -d '/' -f3 | sed -e "s/\.//")
	LATEST_VER_NAME=$(echo $LATEST_VER| sed "s/./.&/4")
	[[ $LATEST_VER =~ ^[0-9]+$ ]]
}
get-installed-ver() {
	INSTALLED_VER=$(wmic PATH Win32_VideoController GET DriverVersion | grep -Eo '[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,4}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')
	INSTALLED_VER_NAME=$(echo $INSTALLED_VER | sed "s/./.&/4")
	[[ $INSTALLED_VER =~ ^[0-9]+$ ]]
}
is-notebook() {
	NOTEBOOK=false
	local VID_DESC=$(wmic PATH Win32_VideoController GET Description | grep "NVIDIA")
	[[ -n "$VID_DESC" ]] && cat "${GDC_PATH}/devices_notebook.txt" | grep -qs "$VID_DESC" && NOTEBOOK=true
}
check-uri() {
	wget -t 1 -T 3 -q --spider "$1"
}
create-driver-uri() {
	local DOWNLOAD_MIRROR="http://us.download.nvidia.com"
	DOWNLOAD_URI="${DOWNLOAD_MIRROR}${FILE_DATA}"
	$INTERNATIONAL && DOWNLOAD_URI=$(echo $DOWNLOAD_URI | sed -e "s/english/international/")
	check-uri "$DOWNLOAD_URI"
}
check-versions() {
	UPDATE=false
	[[ $INSTALLED_VER -lt $LATEST_VER ]] && UPDATE=true
}
update-txt() {
	$UPDATE || echo -e "Already latest version: $INSTALLED_VER_NAME"
	$UPDATE && echo -e "New version available!\nCurrent: $INSTALLED_VER_NAME\nLatest:  $LATEST_VER_NAME"
}
ask-prompt-setup() {
	ask "Download, Extract, and Install new version ( ${LATEST_VER_NAME} ) now?"
}
download-driver() {
	echo -e "Downloading latest version into \"${DOWNLOAD_PATH}\"..."
	wget -N -P "$DOWNLOAD_PATH" "$DOWNLOAD_URI"
}
extract-package() {
	echo -ne "Extracting new driver archive..."
	SOURCE_ARCHIVE="$(cygpath -wa "${DOWNLOAD_PATH}/${FILE_NAME}")"
	EXTRACT_PATH="${EXTRACT_PREFIX}\GDC-${LATEST_VER_NAME}-$(date +%m%y%S)"
	7z x "$SOURCE_ARCHIVE" -o"$EXTRACT_PATH" $EXCLUDE_PKGS >/dev/null && echo "Done"
}
compile-setup-args() {
	SETUP_ARGS="-nofinish -passive -nosplash -noeula"
	$SILENT && SETUP_ARGS+=" -s"
	$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
	$ATTENDED && SETUP_ARGS=
	$ENABLE_REBOOT_PROMPT || SETUP_ARGS+=" -n"
}
run-installer() {
	echo -ne "Executing installer setup..."
	cygstart -w "${EXTRACT_PATH}/setup.exe" "$SETUP_ARGS" && echo "Done"
}
7zip() {
	7z-find || 7z-dl || return 1
	[[ -z $SEVEN_ZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	ask "7z.exe found. Create symbolic link for 7-Zip?" || { USE_7Z_PATH=true; return 0; }
	local BINPATH=$(which ln | sed -e "s/\/ln//")
	check-path "$BINPATH" && ln -s "$SEVEN_ZIP" "$BINPATH"
}
7z-find() {
	SEVEN_ZIP=
	local PFILES=$(cygpath -wa "$PROGRAMFILES")
	local FIND="$(find "$PFILES" "$PFILES (x86)" -maxdepth 2 -type f -name "7z.exe" -print)"
	for i in "$FIND"; do
		[[ -x "$i" ]] && check-hash "$i" && { SEVEN_ZIP="$i"; return 0; }
	done
	return 1
}

7z-dl() {
	local URI="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
	ask "Download 7-Zip v9.22 x86_64 msi package?" || return 1
	wget -N -P "$DOWNLOAD_PATH" "$URI" &&  7z-inst || return 1
	7z-find
}
7z-inst() {
	local MSIEXEC="${ROOT_PATH}/Windows/System32/msiexec"
	check-file x "$MSIEXEC" || return 1
	ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2" && local PASSIVE="/passive"
	"$MSIEXEC" $PASSIVE /norestart /i "$(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi")" || return 1
}
get-deps-array() {
	DEPS=('wget' '7z')
}

get-gdc-path || error "validating scripts execution path :: $GDC_PATH"
check-os-ver || error "Unsupported OS Version :: $OS_VERSION"
check-arch-type || error "Unsupported architecture :: $ARCH_TYPE"
check-path "$ROOT_PATH" || error "validating root path :: $ROOT_PATH"

# get passed args opts
while getopts asyd:cVCAirh OPTIONS; do
	case "${OPTIONS}" in
		a) ATTENDED=true				;;
		s) SILENT=true					;;
		y) YES_TO_ALL=true				;;
		d) DOWNLOAD_PATH="$OPTARG"		;;
		c) CLEAN_INSTALL=true			;;
		V) usage | tail -n 1; exit 0	;;
		C) CHECK_ONLY=true				;;
		A) ATTENDED=true; EXCLUDE_PKGS=	;;
		i) INTERNATIONAL=true			;;
		r) ENABLE_REBOOT_PROMPT=true	;;
		h) usage; exit 0				;;
		*) usage; exit 1				;;
	esac
done
shift $(($OPTIND - 1))

check-path "$DOWNLOAD_PATH" || error "validating download path :: $DOWNLOAD_PATH"

echo "$GDC_PATH"
exit 0

# check dependencies and foo
get-deps-array
for i in "${DEPS[@]}"; do
	case "$i" in
		7z)	check-hash 7z || 7zip || error "Dependency not found :: $i"	;;
		 *)	check-hash "$i" || error "Dependency not found :: $i"	;;
	esac
done

dev-archive || error "validating devices dbase :: ${GDC_PATH}/devices_notebook.txt"
is-notebook
get-online-data || error "in online data query :: $FILE_DATA"
get-latest-ver || error "invalid driver version string :: $LATEST_VER"
get-installed-ver || error "invalid driver version string :: $INSTALLED_VER"
check-versions
update-txt
$UPDATE || exit 0
$CHECK_ONLY && exit 0
get-latest-name || error "invalid file name returned :: $FILE_NAME"
create-driver-uri || error "validating driver download uri :: $DOWNLOAD_URI"
ask-prompt-setup || error "User cancelled"
download-driver || error "wget downloading file :: $DOWNLOAD_URI"
check-mkdir "${ROOT_PATH}/NVIDIA" || error "creating path :: ${ROOT_PATH}/NVIDIA"
extract-package || error "extracting new driver archive :: $SOURCE_ARCHIVE --> $EXTRACT_PATH"
compile-setup-args
run-installer || error "Installation failed or user interupted"
get-installed-ver || error "invalid driver version string :: $INSTALLED_VER"
check-versions && error "After all that your driver version didn't change!"
echo "Driver update successfull!"
exit 0