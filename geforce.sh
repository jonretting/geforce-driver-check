#!/usr/bin/env bash
# NAME: Geforce Driver Check (GDC) geforce-driver-check
# DESC: Checks for new Nvidia Display Drivers then does an automatted unattended install, or with many more options.
# GIT: git@github.com:jonretting/geforce-driver-check.git
# URL: https://github.com/jonretting/geforce-driver-check/
#
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
VERSION="1.049"

# cutomizable defaults
DOWNLOAD_PATH=			# download data path (overides default /cygdrive/sysdrive/Users/username/Downloads path, but not inline "-d /path")
EXTRACT_PREFIX="${SYSTEMDRIVE}\NVIDIA" # extract driver file here use WIN/DOS path
INTERNATIONAL=false		# true use international driver package version multi language support
USER_AGENT="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0" #agent reported to Nvidia alt wget

# remove these nvidia packages from driver install
EXCLUDE_PKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"

usage () {
	echo "Geforce Driver Check v${VERSION}
Desc: Cleans unused/old inf packages, checks for new version, and installs new version)
Usage: geforce.sh [-asycCAirVh] [-d=\"/download/path\"]
Example: geforce.sh
-a    Attended install (user must traverse Nvidia setup GUI)
-s    Silent install (dont show Nvidia progress bar)
-y    Answer 'yes' to all prompts
-c    Clean install (removes all saved profiles and settings)
-R    Force re-install of latest driver
-d    Specify download location
-C    Only check for new version (returns version#, 0=update available, 1=no update)
-A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
-i    Download international driver package (driver package for non English installs)
-r    Don't disable reboot prompt when reboot is needed (could be buged)
-V    Displays version info
-h    this crupt"
}
get-options () {
	local opts="asyd:cRVCAirh"
	while getopts "$opts" OPTIONS; do
		case "${OPTIONS}" in
			a) ATTENDED=true				;;
			s) SILENT=true					;;
			y) YES_TO_ALL=true				;;
			d) DOWNLOAD_PATH="$OPTARG"		;;
			c) CLEAN_INSTALL=true			;;
			R) REINSTALL=true				;;
			V) echo "Version: $VERSION"; exit 0	;;
			C) CHECK_ONLY=true				;;
			A) ATTENDED=true; EXCLUDE_PKGS=	;;
			i) INTERNATIONAL=true			;;
			r) ENABLE_REBOOT_PROMPT=true	;;
			h) usage; exit 0				;;
			*) usage; exit 1				;;
		esac
	done
}
get-defaults () {
	SILENT=false
	YES_TO_ALL=false
	CHECK_ONLY=false
	ATTENDED=false
	CLEAN_INSTALL=false
	REINSTALL=false
	ENABLE_REBOOT_PROMPT=false
	UPDATE=false
	FAIL=false
}
ask () {
	while true; do
		[ "$2" ] && { local pmt="$2";local def=; }; [ "$2" ] || { local pmt="y/n";local def=; }
		$YES_TO_ALL && { local RPY=Y;local def=Y; }; [ -z "$def" ] && { echo -ne "$1 ";read -p "[$pmt] " RPY; }
		[ -z "$RPY" ] && local RPY=$def; case "$RPY" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
	done
}
error () {
	echo -e "Error: geforce.sh : $1" | tee -a /var/log/messages
	exit 1
}
check-hash () {
	hash "$1" 2>/dev/null
}
check-file () {
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
check-files () {
	for i in $2; do
		check-file $1 $i || return 1
	done
}
check-path () {
	check-file dr "$1"
}
check-mkdir () {
	check-path "$1" || mkdir -p "$1"
}
check-cygwin () {
	[[ "$OSTYPE" == "cygwin" ]]
}
check-os-ver () {
	local wmic="$(wmic os get version | grep -oE ^6\.[1-3]{1})"
	local cygw="$(uname -s | grep -oE 6\.[1-3]{1})"
	OS_VERSION="Windows NT $cygw"
	[[ -n "$wmic" && -n "$cygw" && "$wmic" == "$cygw" ]]
}
check-windows-arch () {
	local wmic="$(wmic OS get OSArchitecture /value | grep -o '64-bit')"
	local path="$(cd -P "$(cygpath -W)"; cd ../Program\ Files\ \(x86\) 2>/dev/null && echo "64-bit")"
	WINDOWS_ARCH="$wmic"
	[[ -n "$wmic" && -n "$path" && "$wmic" == "$path" ]]
}
get-username () {
	local winuser="$USERNAME"
	local cyguser="$(whoami)"
	[[ -n "$winuser" ]] && GDC_USER="$winuser" || GDC_USER="$cyguser"
	[[ -n "$GDC_USER" ]]
}
devices-archive () {
	if ! check-files rs "${GDC_PATH}/devices_notebook.txt ${GDC_PATH}/devices_desktop.txt"; then
		tar xf "${GDC_PATH}/devices_dbase.tar.gz" -C "${GDC_PATH}"
		check-files rs "${GDC_PATH}/devices_notebook.txt ${GDC_PATH}/devices_desktop.txt"
	fi
}
get-gdc-path () {
	local src="${BASH_SOURCE[0]}"
	while [[ -h "$src" ]]; do
		local dir="$(cd -P "$(dirname "$src")" && pwd)"
		local src="$(readlink "$src")"
		[[ $src != /* ]] && local src="$dir/$src"
		let local c=c+1; [[ $c -gt 3 ]] && return 1
	done
	GDC_PATH="$(cd -P "$(dirname "$src")" && pwd)"
	check-path "$GDC_PATH"
}
get-root-path () {
	[[ -n "$SYSTEMDRIVE" ]] && ROOT_PATH="$(cygpath "$SYSTEMDRIVE")"
	check-path "$ROOT_PATH" && return 0
	ROOT_PATH="$(cd -P "$(cygpath -W)"; cd .. && pwd)"
	check-path "$ROOT_PATH" && return 0
	ROOT_PATH="$(which explorer.exe | sed 's/.Windows\/explorer\.exe//')"
	check-path "$ROOT_PATH"
}
get-download-path () {
	[[ -n "$SYSTEMDRIVE" ]] && check-path "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="$(cygpath -O | sed 's/Documents/Downloads/')"
	check-path "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="${ROOT_PATH}/NVIDIA/Downloads"
	check-mkdir "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="$(cd -P "$(cygpath -O)" && cd ../Downloads && pwd)"
	check-path "$DOWNLOAD_PATH"
}
get-online-data () {
	local desktop_id="95"
	local notebook_id="92"
	local link="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
	$NOTEBOOK && local link+="$notebook_id" || local link+="$desktop_id"
	local link="$(wget -U "$USER_AGENT" --no-cookies -qO- 2>/dev/null "$link" | awk '/driverResults.aspx/ {print $4}' | awk -F"'" 'NR==1 {print $2}')"
	FILE_DATA="$(wget -U "$USER_AGENT" --no-cookies -qO- 2>/dev/null "$link" | awk 'BEGIN {FS="="} /url=/ {gsub("&lang","");print $3}')"
	[[ "$FILE_DATA" == *.exe ]]
}
get-latest-name () {
	[[ "$1" -eq 1 ]] && get-online-data
	FILE_NAME="$(echo "$FILE_DATA" | cut -d '/' -f4)"
	[[ "$FILE_NAME" == *.exe ]]
}
get-latest-ver () {
	[[ "$1" -eq 1 ]] && get-online-data
	LATEST_VER="$(echo "$FILE_DATA" | cut -d '/' -f3 | sed -e 's/\.//')"
	LATEST_VER_NAME="$(echo "$LATEST_VER" | sed "s/./.&/4")"
	[[ "$LATEST_VER" =~ ^[0-9]+$ ]]
}
get-installed-data () {
	INSTALLED_DATA="$(wmic PATH Win32_videocontroller WHERE "AdapterCompatibility='NVIDIA' AND Availability='3'" GET DriverVersion,Description /value | sed 's/\r//g;s/^M$//;/^$/d')"
	grep -q "NVIDIA" <<< "$INSTALLED_DATA"
}
get-installed-ver () {
	INSTALLED_VER="$(echo "$INSTALLED_DATA" | awk -F"=" '/Version/ {print $2}' | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')"
	INSTALLED_VER_NAME="$(echo "$INSTALLED_VER" | sed 's/./.&/4')"
	[[ "$INSTALLED_VER" =~ ^[0-9]+$ ]]
}
get-adapter () {
	NOTEBOOK=false
	VID_DESC="$(echo "$INSTALLED_DATA" | awk -F"=" '/NVIDIA/ {print $2}')"
	if [[ -n "$VID_DESC" ]]; then 
		cat "${GDC_PATH}/devices_notebook.txt" | grep -wqs "$VID_DESC" && { NOTEBOOK=true; return 0; }
		cat "${GDC_PATH}/devices_desktop.txt" | grep -wqs "$VID_DESC" || return 1
	else
		return 1
	fi
}
check-uri () {
	wget -U "$USER_AGENT" --no-cookies -t 1 -T 3 -q --spider "$1"
}
create-driver-uri () {
	[[ $1 -eq 1 ]] && get-online-data
	local downloadmirror="http://us.download.nvidia.com"
	DOWNLOAD_URI="${downloadmirror}${FILE_DATA}"
	$INTERNATIONAL && DOWNLOAD_URI=$(echo $DOWNLOAD_URI | sed -e "s/english/international/")
	check-uri "$DOWNLOAD_URI"
}
check-versions () {
	if [[ "$INSTALLED_VER" -lt "$LATEST_VER" ]]; then
		UPDATE=true; REINSTALL=false
	elif $REINSTALL && [[ "$INSTALLED_VER" -eq "$LATEST_VER" ]]; then
		REINSTALL=true
	elif [[ "$INSTALLED_VER" -gt "$LATEST_VER" ]]; then
		FAIL=true
	fi
}
update-txt () {
	$FAIL && error "Your installed Version is somehow newer than NVIDIA latest version"
	$REINSTALL && echo "Installed verison: $INSTALLED_VER_NAME, re-installing: $LATEST_VER_NAME" && return 0
	$UPDATE || echo "Already latest version: $INSTALLED_VER_NAME" 
	$UPDATE && echo -e "New version available!\nCurrent: $INSTALLED_VER_NAME\nLatest:  $LATEST_VER_NAME"
}
ask-prompt-setup () {
	local msg="Download, Extract, and Install new version"
	ask "$msg ( ${LATEST_VER_NAME} ) now?"
}
ask-reinstall () {
	ask "Are you sure you would like to re-install version: ${LATEST_VER_NAME}?"
}
validate-download  () {
	echo -ne "Making sure previously downloaded archive size is valid..."
	local lsize=$(stat -c %s "${DOWNLOAD_PATH}/${FILE_NAME}" 2>/dev/null)
	local rsize="$(wget -U "$USER_AGENT" --no-cookies --spider -qSO- 2>&1 "$DOWNLOAD_URI" | awk '/Length/ {print $2}')"
	[[ $lsize -eq $rsize ]] || { echo "Failed"; sleep 2; return 1; }
	echo "Done"
	echo "Testing archive integrity..."
	"$7Z" t "$(cygpath -wa "${DOWNLOAD_PATH}/${FILE_NAME}")"
}
download-driver () {
	echo "Downloading latest version into \"${DOWNLOAD_PATH}\"..."
	[[ $1 == "again" ]] && rm -f "${DOWNLOAD_PATH}/${FILE_NAME}" || local opts='-N'
	wget -U "$USER_AGENT" --no-cookies $opts -P "$DOWNLOAD_PATH" "$DOWNLOAD_URI"
}
extract-package () {
	echo -ne "Extracting new driver archive..."
	SOURCE_ARCHIVE="$(cygpath -wa "${DOWNLOAD_PATH}/${FILE_NAME}")"
	EXTRACT_PATH="${EXTRACT_PREFIX}\GDC-${LATEST_VER_NAME}-$(date +%m%y%S)"
	"$SZ" x "$SOURCE_ARCHIVE" -o"$EXTRACT_PATH" $EXCLUDE_PKGS >/dev/null && echo "Done"
}
compile-setup-args () {
	SETUP_ARGS="-nofinish -passive -nosplash -noeula"
	$SILENT && SETUP_ARGS+=" -s"
	$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
	$ATTENDED && SETUP_ARGS=
	$ENABLE_REBOOT_PROMPT || SETUP_ARGS+=" -n"
}
run-installer () {
	echo -ne "Executing installer setup..."
	cygstart -w --action=runas "${EXTRACT_PATH}/setup.exe" "$SETUP_ARGS" && echo "Done"
}
check-result () {
	get-installed-data
	get-installed-ver
	[[ $INSTALLED_VER -eq $LATEST_VER ]]
}
7zip () {
	7z-find || 7z-dl || return 1
	[[ -z "$SEVEN_ZIP" ]] && error "can't find 7-Zip installation, please install 7-Zip."
	ask "7z.exe found. Create symbolic link for 7-Zip?" || { SZ="$SEVEN_ZIP"; return 0; }
	local binpath="$(dirname $(which ls))"
	check-path "$binpath" && ln -s "$SEVEN_ZIP" "$binpath"
}
7z-find () {
	local PFILES="$(cd -P "$(cygpath -W)"; cd .. && pwd)/Program Files"
	local FIND="$(find "$PFILES" "$PFILES (x86)" -maxdepth 2 -type f -name "7z.exe" -print)"
	for i in "$FIND"; do
		[[ -x "$i" ]] && check-hash "$i" && { SEVEN_ZIP="$i"; return 0; }
	done
	return 1
}
7z-dl () {
	local URI="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
	ask "Download 7-Zip v9.22 x86_64 msi package?" || return 1
	get-download-path || { echo "error getting download path, try [-d /path]"; return 1; }
	wget -U "$USER_AGENT" --no-cookies -N --no-check-certificate -P "$DOWNLOAD_PATH" "$URI" &&  7z-inst || return 1
	7z-find
}
7z-inst () {
	local MSIEXEC="$(cygpath -S)/msiexec.exe"
	check-file x "$MSIEXEC" || return 1
	ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2" && local PASSIVE="/passive"
	cygstart -w --action=runas "$MSIEXEC" $PASSIVE /norestart /i "$(cygpath -wal "${DOWNLOAD_PATH}/7z922-x64.msi")" || return 1
}
get-deps-array () {
	DEPS=('uname' 'cygpath' 'find' 'sed' 'cygstart' 'grep' 'wget' '7z' 'wmic' 'tar' 'gzip')
}
check-deps () {
	for i in "${DEPS[@]}"; do
		case "$i" in
			wmic) check-hash wmic || PATH="${PATH}:$(cygpath -S)/Wbem"; check-hash wmic || error "adding wmic to PATH" ;;
			  7z) check-hash 7z && SZ="7z" || 7zip || error "Dependency not found :: $i" ;;
		  	   *) check-hash "$i" || error "Dependency not found :: $i"	;;
		esac
	done
}
get-defaults
get-options "$@" && shift $(($OPTIND-1))
get-deps-array && check-deps
check-cygwin || error "detecting Cygwin (uname -o) :: $CYGWIN"
check-os-ver || error "Unsupported OS Version"
check-windows-arch || error "Unsupported architecture"
get-installed-data || error "did not find NVIDIA graphics adapter"
get-username || echo "Warning: could not retrieve current Windows username :: $USERNAME"
get-gdc-path || error "validating scripts execution path :: $GDC_PATH"
get-root-path || error "validating root path :: $ROOT_PATH"
get-download-path || error "validating download path :: $DOWNLOAD_PATH"
devices-archive || error "validating devices dbase :: ${GDC_PATH}/devices_notebook.txt"
get-adapter || error "not Geforce drivers compatabile adapter :: $VID_DESC"
get-online-data || error "in online data query :: $FILE_DATA"
get-latest-ver || error "invalid driver version string :: $LATEST_VER"
get-installed-ver || error "invalid driver version string :: $INSTALLED_VER"
check-versions
update-txt
$UPDATE || $REINSTALL || exit 0
$CHECK_ONLY && exit 0
get-latest-name || error "invalid file name returned :: $FILE_NAME"
create-driver-uri || error "validating driver download uri :: $DOWNLOAD_URI"
if $REINSTALL; then
	ask-reinstall || error "User cancelled"
	check-file "${DOWNLOAD_PATH}/$FILE_NAME"
	validate-download || download-driver "again" || error "wget downloading file :: $DOWNLOAD_URI"
elif $UPDATE; then
	ask-prompt-setup || error "User cancelled"
	download-driver || error "wget downloading file :: $DOWNLOAD_URI"
fi
check-mkdir "${ROOT_PATH}/NVIDIA" || error "creating path :: ${ROOT_PATH}/NVIDIA"
extract-package || error "extracting new driver archive :: $SOURCE_ARCHIVE --> $EXTRACT_PATH"
compile-setup-args
run-installer || error "Installation failed or user interupted"
get-installed-ver || error "invalid driver version string :: $INSTALLED_VER"
check-result || error "After all that your driver version didn't change!"
echo "Driver update successfull!"
exit 0
