exit 0
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

VERSION="1.022"

# cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror
ROOTPATH="/cygdrive/c" #$(cygpath -W | sed -e "s/\/Windows//")

# default vars
LINK="http://www.nvidia.com/Download/processFind.aspx?psid=95&pfid=695&osid=19&lid=1&whql=&lang=en-us"
EXCLUDEPKGS="-xr!GFExperience* -xr!NV3DVision* -xr!Display.Update -xr!Display.Optimus -xr!MS.NET -xr!ShadowPlay -xr!LEDVisualizer -xr!NvVAD"
SETUPARGS="-nofinish -passive -nosplash -noeula -n" #-n noreboot
CWD=$PWD

# clear default vars
FILEDATA=
FILENAME=
LATESTVER=
REMOEMS=
OLDOEMINF=
CURRENTVER=
DLURI=
SZIP=
EXTRACTSUBDIR=
LATESTVERNAME= #adds decimal
CURRENTVERNAME= #adds decimal

# default flags
SILENT=false
YES=false
USE7ZPATH=false
CHECKONLY=false
ATTENDED=false
CLEANINSTALL=false

# binary dependency array
DEPS=('PnPutil' 'wget' '7z' 'cygpath')

error() { echo "Error: $1"; exit 1; }

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

find7z() {
	local find=$(find . -maxdepth 1 -type d -name "7-Zip" -print | sed -e "s/\.\///")
	[[ "$find" == "7-Zip" ]] && [[ -e "${find}/7z.exe" ]] && SZIP="${PWD}/${find}/7z.exe"
	cd "$CWD"
}

#needs cleanup/optimization/abstraction
7zip() {
	checkdir "${ROOTPATH}/Program Files" &&	cd "${ROOTPATH}/Program Files" && find7z
	[[ -z $SZIP ]] && checkdir "${ROOTPATH}/Program Files (x86)" &&	cd "${ROOTPATH}/Program Files (x86)" &&	find7z
	[[ -z $SZIP ]] && error "can't find 7-Zip installation, please install 7-Zip."
	if ask "7z.exe found. Create symbolic link for 7-Zip?"; then
		local BINPATH=$(which ln | sed -e "s/\/ln//")
		checkdir "$BINPATH" && ln -s "$SZIP" "$BINPATH"
	else
		USE7ZPATH=true
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
		d) DOWNLOADDIR="$OPTARG"	;;
		c) CLEANINSTALL=true	;;
		V) usage | tail -n 1; exit 0	;;
		C) CHECKONLY=true	;;
		A) ATTENDED=true; EXCLUDEPKGS=	;;
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

# check default download directory
checkdir "$DOWNLOADDIR" || error "Directory not found \"$DOWNLOADDIR\""

# remove unused oem*.inf packages and set OLDOEMINF from in use
REMOEMS=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/Published/ {print $4}')
if [[ $(echo "$REMOEMS" | wc -l) -gt 1 ]]; then
	for REOEM in $REMOEMS; do
		[[ $REOEM == oem*.inf ]] || error "Unexpected value in REOEMS array :: $REOEM"
		PnPutil -d $REOEM >/dev/null || OLDOEMINF="$REOEM"
	done
fi

# file data query
FILEDATA=$(wget -qO- $(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1) | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
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
[[ $CURRENTVER =~ ^[0-9]+$ ]] || error "CURRENTVER not a number :: $CURRENTVER"
CURRENTVERNAME=$(echo $CURRENTVER | sed 's/./.&/4')

# old oem*.inf file if not already detected
[[ -z $OLDOEMINF ]] && OLDOEMINF=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | grep -B 3 "$(echo "$CURRENTVER" | sed 's/./.&/2')" | awk '/Published/ {print $4}')
[[ $OLDOEMINF == oem*.inf ]] || error "Old oem*.inf file :: $OLDOEMINF"

# store full uri
DLURI="${DLHOST}${FILEDATA}"

# check versions
if [[ $CURRENTVER -eq $LATESTVER ]]; then
	$CHECKONLY && exit 1
	echo "Already latest version: $CURRENTVERNAME"
	exit 0
fi
$CHECKONLY && { echo "$CURRENTVERNAME --> $LATESTVERNAME"; exit 0; }

# run tasks
echo -e "New version available!
Current: $CURRENTVERNAME
Latest:  $LATESTVERNAME
Downloading latest version into \"$DOWNLOADDIR\"..."
cd "$DOWNLOADDIR" || error "Changing to download directory \"$DOWNLOADDIR\""
wget -N "$DLURI" || error "wget downloading file \"$DLURI\""

# ask to isntall
ask "Extract and Install new version ($LATESTVERNAME) now?" || { echo "User cancelled"; exit 0; }

# unarchive new version download
checkdir "${ROOTPATH}/NVIDIA" || mkdir "${ROOTPATH}/NVIDIA" || error "creating directory :: \"$ROOTPATH/NVIDIA\""
EXTRACTSUBDIR="${ROOTPATH}/NVIDIA/GDC-${LATESTVERNAME}"
echo -ne "Extracting new driver archive..."
checkdir "$EXTRACTSUBDIR" && rm -rf "$EXTRACTSUBDIR"
7z x "$(cygpath -wap "${DOWNLOADDIR}/${FILENAME}")" -o"$(cygpath -wap "${EXTRACTSUBDIR}")" $EXCLUDEPKGS >/dev/null || error "extracting new download"
echo "Done"

# create setup.exe options args
$SILENT && SETUPARGS+=" -s"
$CLEANINSTALL && SETUPARGS+=" -clean"
$ATTENDED && SETUPARGS=

# run the installer with args
echo -ne "Executing installer setup..."
cygstart -w "$EXTRACTSUBDIR/setup.exe" "$SETUPARGS" || error "Installation failed or user interupted"
echo "Done"

# remove old oem inf package
echo -ne "Removing old driver package..."
PnPutil -d $OLDOEMINF >/dev/null || error "Removing old oem*.inf package (maybe in use):: $OLDOEMINF"
echo "Done"

# final check verify new version
CURRENTVER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENTVER -eq $LATESTVER ]] || error "After all that your driver version didn't change!"
echo "Driver update successfull!"

exit 0