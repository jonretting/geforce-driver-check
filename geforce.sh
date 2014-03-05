#!/usr/bin/env bash
# NAME: Geforce Driver Check (GDC) geforce-driver-check
# DESC: Checks for new Nvidia Display Drivers then does an automatted unattended install, or with many more options.
# GIT: git@github.com:jonretting/geforce-driver-check.git
# URL: https://github.com/jonretting/geforce-driver-check/
#
# Copyright (c) 2014 Jon Retting
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
VERSION="1.0511"

# cutomizable defaults (respects environment defined vars) inline cmd over-rides both
DOWNLOAD_PATH="${DOWNLOAD_PATH:=}"	# download path ex: DOWNLOAD_PATH="${DOWNLOAD_PATH:=/this/download/path}"
EXTRACT_PREFIX="${EXTRACT_PREFIX:-$SYSTEMDRIVE\NVIDIA}" # extract driver file here use WIN/DOS path
INTERNATIONAL="${INTERNATIONAL:-false}"	# use international driver package version multi language support
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0}"	# agent passed to wget

# remove these nvidia packages from driver install
EXCLUDED_PKGS=("GFExperience*" "NV3DVision*" "Display.Update" "Display.Optimus" "Display.NView" "Network.Service" "MS.NET" "ShadowPlay" "LEDVisualizer" "NvVAD")

usage () {
	echo " Geforce Driver Check $VERSION
 Desc: Cleans unused/old inf packages, checks for new version, and installs new version)
 Usage: geforce.sh [-asycCAirVh] [-d=\"/download/path\"]
 Example: geforce.sh
 -a    Attended install (user must traverse Nvidia setup GUI)
 -s    Silent install (dont show Nvidia progress bar)
 -y    Answer 'yes' to all prompts
 -c    Clean install (removes all saved profiles and settings)
 -R    Force re-install of latest driver
 -d    Specify download location
 -v    Verbose
 -C    Only check for new version (returns version#, 0=update available, 1=no update)
 -A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
 -i    Download international driver package (driver package for non English installs)
 -r    Don't disable reboot prompt when reboot is needed (could be buged)
 -V    Displays version info
 -h    this crupt"
}
getoptions () {
	getdefaults
	local opts="asyd:cRVCAirh"
	while getopts "$opts" OPTIONS; do
		case "$OPTIONS" in
			a) ATTENDED=true ;;
			s) SILENT=true ;;
			y) YES_TO_ALL=true ;;
			d) DOWNLOAD_PATH="$OPTARG" ;;
			c) CLEAN_INSTALL=true ;;
			v) VERBOSE=true ;;
			R) REINSTALL=true ;;
			V) echo "Version $VERSION"; exit 0 ;;
			C) CHECK_ONLY=true ;;
			A) ATTENDED=true; EXCLUDE_PKGS= ;;
			i) INTERNATIONAL=true ;;
			r) ENABLE_REBOOT_PROMPT=true ;;
			h) usage; exit 0 ;;
			*) usage; exit 1 ;;
		esac
	done
}
getdefaults () {
	SILENT=false
	YES_TO_ALL=false
	CHECK_ONLY=false
	ATTENDED=false
	CLEAN_INSTALL=false
	REINSTALL=false
	ENABLE_REBOOT_PROMPT=false
	UPDATE=false
	VERBOSE=false
	LOGGER=false
	FAIL=false
	SCRIPTSOURCE="$0"
}
ask () {
	while true; do
		[ "$2" ] && { local pmt="$2";local def=; }; [ "$2" ] || { local pmt="y/n";local def=; }
		$YES_TO_ALL && { local RPY=Y;local def=Y; }; [ -z "$def" ] && { printf "%s $1 [$pmt] ";read RPY; }
		[ -z "$RPY" ] && local RPY=$def; case "$RPY" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
	done
}
error () {
	printf "%s$(date): Error: geforce.sh : $1" | tee -a /var/log/messages
	exit 1
}
checkhash () {
	hash "$1" 2>/dev/null
}
checkfile () {
	while [ ${#} -gt 0 ]; do
		case "$1" in
			x) [ -x "$2" ] || return 1 ;;
			r) [ -r "$2" ] || return 1 ;;
			s) [ -s "$2" ] || return 1 ;;
		   rs) [ -r "$2" ] && [ -s "$2" ] || return 1 ;; #file read > 0
			h) [ -h "$2" ] || return 1 ;;
		   dr) [ -d "$2" ] && [ -r "$2" ] || return 1 ;; #path read
		  	*) [ -e "$1" ] || return 1 ;;
		esac
		shift
	done
}
checkfiles () {
	local files="$2"; local opts="$1"
	for file in $files; do
		checkfile "$opts" "$file" || return 1
	done
}
checkpath () {
	checkfile dr "$1"
}
checkmkdir () {
	checkpath "$1" || mkdir -p "$1"
}
checkcygwin () {
	[ "$(uname -o)" = "Cygwin" ]
}
checkosver () {
	local wmic="$(wmic os get version | grep -oE ^6\.[1-3]{1})"
	local cygw="$(uname -s | grep -oE 6\.[1-3]{1})"
	[ -n "$wmic" ] && [ -n "$cygw" ] && [ "$wmic" = "$cygw" ]
}
checkwindowsarch () {
	local wmic="$(wmic OS get OSArchitecture /value | grep -o '64-bit')"
	local path="$(cd -P "$(cygpath -W)"; cd ../Program\ Files\ \(x86\) 2>/dev/null && echo "64-bit")"
	[ -n "$wmic" ] && [ -n "$path" ] && [ "$wmic" = "$path" ]
}
devicesarchive () {
	checkfiles rs "$GDC_PATH/devices_notebook.txt $GDC_PATH/devices_desktop.txt" && return 0
	tar xf "$GDC_PATH/devices_dbase.tar.gz" -C "$GDC_PATH"
	checkfiles rs "$GDC_PATH/devices_notebook.txt $GDC_PATH/devices_desktop.txt"
}
getgdcpath () {
	local src="$SCRIPTSOURCE"
	while [ -h "$src" ]; do
		local dir="$(cd -P "$(dirname "$src")" && pwd)"
		local src="$(readlink "$src")"
		[ $src != /* ] && local src="$dir/$src"
		local c=$(($c+1)); [ "$c" -gt 3 ] && return 1
	done
	GDC_PATH="$(cd -P "$(dirname "$src")" && pwd)"
	checkpath "$GDC_PATH"
}
getrootpath () {
	[ -n "$SYSTEMDRIVE" ] && ROOT_PATH="$(cygpath "$SYSTEMDRIVE")"
	checkpath "$ROOT_PATH" && return 0
	ROOT_PATH="$(cd -P "$(cygpath -W)"; cd .. && pwd)"
	checkpath "$ROOT_PATH" && return 0
	ROOT_PATH="$(which explorer.exe | sed 's/.Windows\/explorer\.exe//')"
	checkpath "$ROOT_PATH"
}
getdownloadpath () {
	[ -n "$SYSTEMDRIVE" ] && checkpath "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="$(cygpath -O | sed 's/Documents/Downloads/')"
	checkpath "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="$EXTRACT_PREFIX/Downloads"
	checkmkdir "$DOWNLOAD_PATH" && return 0
	DOWNLOAD_PATH="$(cd -P "$(cygpath -O)" && cd ../Downloads && pwd)"
	checkpath "$DOWNLOAD_PATH"
}
getwget () {
	wget -U "$USER_AGENT" --no-cookies -qO- 2>/dev/null "$1"
}
getonlinedata () {
	local desktop_id="95"
	local notebook_id="92"
	local link="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
	$NOTEBOOK && local link+="$notebook_id" || local link+="$desktop_id"
	local link="$(getwget "$link" | awk '/driverResults.aspx/ {print $4}' | awk -F\' 'NR==1 {print $2}')"
	FILE_DATA="$(getwget "$link" | awk 'BEGIN {FS="="} /url=/ {gsub("&lang","");print $3}')"
	[[ "$FILE_DATA" == '/Windows/'*'.exe' ]]
}
getlatestname () {
	[ "$1" = true ] && getonlinedata
	FILE_NAME="$(echo ${FILE_DATA##/*/})"
	$INTERNATIONAL && FILE_NAME="$(echo ${FILE_NAME/english/international/})"
	[[ "$FILE_NAME" == *.exe ]]
}
getlatestver () {
	[ "$1" = true ] && getonlinedata
	LATEST_VER_NAME="$(echo $FILE_DATA | cut -d\/ -f3)"
	LATEST_VER="$(echo ${LATEST_VER_NAME//\./})"
	[[ "$LATEST_VER" =~ ^[0-9]+$ ]]
}
getinstalleddata () {
	INSTALLED_DATA="$(wmic PATH Win32_videocontroller WHERE "AdapterCompatibility='NVIDIA' AND Availability='3'" GET DriverVersion,Description /value | sed 's/\r//g;s/^M$//;/^$/d')"
	echo "$INSTALLED_DATA" | grep -q "NVIDIA"
}
getinstalledver () {
	[ "$1" = true ] && getinstalleddata
	INSTALLED_VER="$(echo ${INSTALLED_DATA##*=} | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')"
	INSTALLED_VER_NAME="$(echo $INSTALLED_VER | sed 's/./.&/4')"
	[[ "$INSTALLED_VER" =~ ^[0-9]+$ ]]
}
getadapter () {
	[ "$1" = true ] && getinstalleddata
	NOTEBOOK=false
	VID_DESC="$(echo "$INSTALLED_DATA" | awk -F\= '/NVIDIA/ {print $2}')"
	[ -z "$VID_DESC" ] && return 1
	cat "$GDC_PATH/devices_notebook.txt" | grep -wqs "$VID_DESC" && { NOTEBOOK=true; return 0; }
	cat "$GDC_PATH/devices_desktop.txt" | grep -wqs "$VID_DESC" || return 1
}
checkurl () {
	wget -U "$USER_AGENT" --no-cookies -t 1 -T 3 -q --spider "$1"
}
createdriveruri () {
	[ "$1" = true ] && getonlinedata
	local url="http://us.download.nvidia.com"
	DOWNLOAD_URL="$url$FILE_DATA"
	$INTERNATIONAL && DOWNLOAD_URL="$(echo $DOWNLOAD_URL | sed -e 's/english/international/')"
	checkurl "$DOWNLOAD_URL"
}
checkversions () {
	if [ "$INSTALLED_VER" -lt "$LATEST_VER" ]; then
		UPDATE=true; REINSTALL=false
	elif $REINSTALL && [ "$INSTALLED_VER" -eq "$LATEST_VER" ]; then
		REINSTALL=true
	elif [ "$INSTALLED_VER" -gt "$LATEST_VER" ]; then
		FAIL=true
	fi
	updatetxt
}
updatetxt () {
	$FAIL && error "Your installed Version is somehow newer than NVIDIA latest version"
	$REINSTALL && { echo "Installed verison: $INSTALLED_VER_NAME, re-installing: $LATEST_VER_NAME"; return 0; }
	$UPDATE || { echo "Already latest version: $INSTALLED_VER_NAME"; return 0; }
	$UPDATE && echo -e "New version available!\nCurrent: $INSTALLED_VER_NAME\nLatest: $LATEST_VER_NAME"
}
askpromptsetup () {
	local msg="Download, Extract, and Install new version"
	ask "$msg ( $LATEST_VER_NAME ) now?"
}
askreinstall () {
	ask "Are you sure you would like to re-install version: $LATEST_VER_NAME?"
}
validatedownload  () {
	printf "%sMaking sure previously downloaded archive size is valid..."
	local lsize="$(stat -c %s "$DOWNLOAD_PATH/$FILE_NAME" 2>/dev/null)"
	local rsize="$(wget -U "$USER_AGENT" --no-cookies --spider -qSO- 2>&1 "$DOWNLOAD_URL" | awk '/Length/ {print $2}')"
	[ "$lsize" -eq "$rsize" ] || { echo "Failed"; sleep 2; return 1; }
	echo "Done"
	echo "Testing archive integrity..."
	"$7Z" t "$(cygpath -wa "$DOWNLOAD_PATH/$FILE_NAME")"
}
downloaddriver () {
	echo "Downloading latest version into \"$DOWNLOAD_PATH\"..."
	[ "$1" = true ] && rm -f "$DOWNLOAD_PATH/$FILE_NAME" || local opts='-N'
	wget -U "$USER_AGENT" --no-cookies $opts -P "$DOWNLOAD_PATH" "$DOWNLOAD_URL"
}
getexcludedpkgs () {
	for pkg in "${EXCLUDED_PKGS[@]}"; do
		echo -n "-xr!$pkg "
	done
}
extractpkg () {
	printf "%sExtracting new driver archive..."
	local src="$(cygpath -wa "$DOWNLOAD_PATH/$FILE_NAME")"
	EXTRACT_PATH="$EXTRACT_PREFIX\GDC-$LATEST_VER-$(date +%m%y%S)"
	"$SZ" x "$src" -o"$EXTRACT_PATH" $(getexcludedpkgs) -y 2>&1 >/dev/null && echo "Done"
}
compsetupargs () {
	SETUP_ARGS="-nofinish -passive -nosplash -noeula"
	$SILENT && SETUP_ARGS+=" -s"
	$CLEAN_INSTALL && SETUP_ARGS+=" -clean"
	$ATTENDED && SETUP_ARGS=
	$ENABLE_REBOOT_PROMPT || SETUP_ARGS+=" -n"
}
runinstaller () {
	compsetupargs
	printf "%sExecuting installer setup..."
	cygstart -w --action=runas "$EXTRACT_PATH/setup.exe" "$SETUP_ARGS" && echo "Done"
}
checkresult () {
	getinstalleddata
	getinstalledver
	[ "$INSTALLED_VER" -eq "$LATEST_VER" ]
}
7zip () {
	7zfind || 7zdl || return 1
	[ -z "$SEVEN_ZIP" ] && error "can't find 7-Zip installation, please install 7-Zip."
	ask "7z.exe found. Create symbolic link for 7-Zip?" || { SZ="$SEVEN_ZIP"; return 0; }
	local binpath="$(dirname $(which ls))"
	checkpath "$binpath" && ln -s "$SEVEN_ZIP" "$binpath"
}
7zfind () {
	local pfiles="$(cd -P "$(cygpath -W)"; cd .. && pwd)/Program Files"
	local find="$(find "$pfiles" "$pfiles (x86)" -maxdepth 2 -type f -name "7z.exe" -print)"
	for i in "$find"; do
		[ -x "$i" ] && checkhash "$i" && { SEVEN_ZIP="$i"; return 0; }
	done
	return 1
}
7zdl () {
	local url="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
	ask "Download 7-Zip v9.22 x86_64 msi package?" || return 1
	getdownloadpath || { echo "error getting download path, try [-d /path]"; return 1; }
	wget -U "$USER_AGENT" --no-cookies -N --no-check-certificate -P "$DOWNLOAD_PATH" "$url" &&  7zinst || return 1
	7zfind
}
7zinst () {
	local msiexec="$(cygpath -S)/msiexec.exe"
	checkfile x "$msiexec" || return 1
	ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2" && local passive="/passive"
	cygstart -w --action=runas "$msiexec" $passive /norestart /i "$(cygpath -wal "$DOWNLOAD_PATH/7z922-x64.msi")" || return 1
}
getdepsarray () {
	DEPS=('uname' 'cygpath' 'find' 'sed' 'cygstart' 'grep' 'wget' '7z' 'wmic' 'tar' 'gzip' 'logger')
}
checkdeps () {
	getdepsarray
	for dep in "${DEPS[@]}"; do
		case "$dep" in
		   logger) checkhash logger && LOGGER=true ;;
			 wmic) checkhash wmic || PATH="$PATH:$(cygpath -S)/Wbem"; checkhash wmic || error "adding wmic to PATH" ;;
			   7z) checkhash 7z && SZ="7z" || 7zip || error "Dependency not found :: 7z (7-Zip)" ;;
		  	    *) checkhash "$dep" || error "Dependency not found :: $dep" ;;
		esac
	done
}
getoptions "$@" && shift $(($OPTIND-1))
checkdeps
checkcygwin || error "Cygwin not detected :: $(uname -o)"
checkosver || error "Unsupported OS Version"
checkwindowsarch || error "Unsupported architecture"
getinstalleddata || error "did not find NVIDIA graphics adapter"
getgdcpath || error "validating scripts execution path :: $GDC_PATH"
getrootpath || error "validating root path :: $ROOT_PATH"
getdownloadpath || error "validating download path :: $DOWNLOAD_PATH"
devicesarchive || error "validating devices dbase :: $GDC_PATH/devices_notebook.txt"
getadapter || error "not Geforce drivers compatabile adapter :: $VID_DESC"
getonlinedata || error "in online data query :: $FILE_DATA"
getlatestver || error "invalid driver version string :: $LATEST_VER"
getinstalledver || error "invalid driver version string :: $INSTALLED_VER"
checkversions
$CHECK_ONLY && { $UPDATE && exit 0 || exit 1; }
$UPDATE || $REINSTALL || exit 0
getlatestname || error "invalid file name returned :: $FILE_NAME"
createdriveruri || error "validating driver download uri :: $DOWNLOAD_URL"
if $REINSTALL; then
	askreinstall || error "User cancelled"
	checkfile "$DOWNLOAD_PATH/$FILE_NAME"
	validatedownload || downloaddriver true || error "wget downloading file :: $DOWNLOAD_URL"
elif $UPDATE; then
	askpromptsetup || error "User cancelled"
	downloaddriver || error "wget downloading file :: $DOWNLOAD_URL"
fi
checkmkdir "$ROOT_PATH/NVIDIA" || error "creating path :: $ROOT_PATH/NVIDIA"
extractpkg || error "extracting new driver archive :: $EXTRACT_PREFIX"
runinstaller || error "Installation failed or user interupted"
getinstalledver true || error "invalid driver version string :: $INSTALLED_VER"
checkresult || error "After all that your driver version didn't change!"
echo "Driver update successfull!"
exit 0
