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
GDC_VERSION="1.08"

# cutomizable defaults (respects environment defined vars) inline cmd over-rides both
GDC_DL_PATH="${GDC_DL_PATH:=}"  # download path ex: GDC_DL_PATH="${GDC_DL_PATH:=/this/download/path}"
GDC_EXT_PATH="${GDC_EXT_PATH:-$SYSTEMDRIVE\NVIDIA}" # extract driver file here use WIN/DOS path
GDC_USE_INTL="${GDC_USE_INTL:-false}" # use international driver package version multi language support
GDC_WGET_USR_AGENT="${GDC_WGET_USR_AGENT:-Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0}"    # agent passed to wget

# remove these nvidia packages from driver install
GDC_EXCL_PKGS=("GFExperience*" "NV3DVision*" "Display.Update" "Display.Optimus" "Display.NView" "Network.Service" "MS.NET" "ShadowPlay" "LEDVisualizer" "NvVAD")

gdc_print_usage () {
    printf "%s\n Geforce Driver Check $GDC_VERSION
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
 -h    this crupt\n"
}
gdc_get_options () {
    gdc_get_defaults
    local opts="asyd:cRVCAirh"
    while getopts "$opts" GDC_OPTIONS; do
        case "$GDC_OPTIONS" in
            a) GDC_ATTENDED=true ;;
            s) GDC_SILENT=true ;;
            y) GDC_YESTOALL=true ;;
            d) GDC_DL_PATH="$OPTARG" ;;
            c) GDC_CLEAN_INSTALL=true ;;
            R) GDC_REINSTALL=true ;;
            V) printf "%sVersion $GDC_VERSION\n"; exit 0 ;;
            C) GDC_CHECK_ONLY=true ;;
            A) GDC_ATTENDED=true; GDC_EXCL_PKGS=;;
            i) GDC_USE_INTL=true ;;
            r) GDC_USE_REBOOT_PROMPT=true ;;
            h) gdc_print_usage; exit 0 ;;
            *) gdc_print_usage; exit 1 ;;
        esac
    done
}
gdc_get_defaults () {
    GDC_SILENT=false
    GDC_YESTOALL=false
    GDC_CHECK_ONLY=false
    GDC_ATTENDED=false
    GDC_CLEAN_INSTALL=false
    GDC_REINSTALL=false
    GDC_USE_REBOOT_PROMPT=false
    GDC_UPDATE=false
    GDC_FAIL=false
    GDC_SCRIPT_PATH="$0"
}
gdc_ask () {
    while true; do
        [ "$2" ] && { local pmt="$2";local def=""; }; [ "$2" ] || { local pmt="y/n";local def=""; }
        $GDC_YESTOALL && { local rpy="Y";local def="Y"; }; [ -z "$def" ] && { printf "%s$1 [$pmt] ";read rpy; }
        [ -z "$rpy" ] && local rpy="$def"; case "$rpy" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
    done
}
gdc_log_error () {
    printf "%s$(date): Error: geforce.sh : $1" | tee -a /var/log/messages
    exit 1
}
gdc_check_hash () {
    hash "$1" 2>/dev/null
}
gdc_check_file () {
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
gdc_check_files () {
    local files="$2"; local opts="$1"
    for file in $files; do
        gdc_check_file "$opts" "$file" || return 1
    done
}
gdc_check_path () {
    gdc_check_file dr "$1"
}
gdc_check_mkdir () {
    gdc_check_path "$1" || { mkdir -p "$1" || gdc_log_error "error creating folder paths"; }
}
gdc_check_cygwin () {
    [ "$(uname -o)" = "Cygwin" ]
}
gdc_check_ver_os () {
    [ "$1" = true ] && { wmic os get version /value | grep -Eo '[^=]*$'; return $?; }
    wmic os get version /value | grep -Eq '6\.[1-3]{1}.*'
}
gdc_check_arch_win () {
    [ "$1" = true ] && { wmic OS get OSArchitecture /value | grep -Eo '[^=]*$'; return $?; }
    wmic OS get OSArchitecture /value | grep -q '64-bit'
}
gdc_ext_tar_devices () {
    gdc_check_files rs "$GDC_PATH/devices_notebook.txt $GDC_PATH/devices_desktop.txt" && return 0
    tar xf "$GDC_PATH/devices_dbase.tar.gz" -C "$GDC_PATH"
    gdc_check_files rs "$GDC_PATH/devices_notebook.txt $GDC_PATH/devices_desktop.txt"
}
gdc_get_path_gdc () {
    local src="$GDC_SCRIPT_PATH"
    while [ -h "$src" ]; do
        local dir="$(cd -P "$(dirname "$src")" && pwd)"
        local src="$(readlink "$src")"
        [ "$src" != /* ] && local src="$dir/$src"
        local c=$((c+1)); [ "$c" -gt 3 ] && return 1
    done
    GDC_PATH="$(cd -P "$(dirname "$src")" && pwd)"
    gdc_check_path "$GDC_PATH"
}
gdc_get_path_root () {
    [ -n "$SYSTEMDRIVE" ] && GDC_ROOT_PATH="$(cygpath "$SYSTEMDRIVE")"
    gdc_check_path "$GDC_ROOT_PATH" && return 0
    GDC_ROOT_PATH="$(cd -P "$(cygpath -W)" && { cd .. && pwd; } || return 1)"
    gdc_check_path "$GDC_ROOT_PATH" && return 0
    GDC_ROOT_PATH="$(which explorer.exe | sed 's/.Windows\/explorer\.exe//')"
    gdc_check_path "$GDC_ROOT_PATH"
}
gdc_get_path_download () {
    [ -n "$SYSTEMDRIVE" ] && gdc_check_path "$GDC_DL_PATH" && return 0
    GDC_DL_PATH="$(cygpath -O | sed 's/Documents/Downloads/')"
    gdc_check_path "$GDC_DL_PATH" && return 0
    GDC_DL_PATH="$GDC_EXT_PATH/Downloads"
    gdc_check_mkdir "$GDC_DL_PATH" && return 0
    GDC_DL_PATH="$(cd -P "$(cygpath -O)" && { cd ../Downloads && pwd; } || return 1)"
    gdc_check_path "$GDC_DL_PATH"
}
gdc_get_wget () {
    wget -U "$GDC_WGET_USR_AGENT" --no-cookies -qO- 2>/dev/null "$1"
}   
gdc_get_data_net () {
    local desktop_id="95"
    local notebook_id="92"
    local link="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
    $GDC_NOTEBOOK && local link+="$notebook_id" || local link+="$desktop_id"
    local link="$(gdc_get_wget "$link" | awk '/driverResults.aspx/ {print $4}' | awk -F\' 'NR==1 {print $2}')"
    GDC_FILE_DATA="$(gdc_get_wget "$link" | awk 'BEGIN {FS="="} /url=/ {gsub("&lang","");print $3}')"
    [[ "$GDC_FILE_DATA" == '/Windows/'*'.exe' ]]
}
gdc_get_filename_latest () {
    GDC_FILE_NAME="${GDC_FILE_DATA##/*/}"
    $GDC_USE_INTL && GDC_FILE_NAME="${GDC_FILE_NAME/english/international/}"
    printf "$GDC_FILE_NAME" | grep -Eq "^$GDC_LATEST_VER_NAME\-.*\.exe$" 
}
gdc_get_ver_latest () {
    GDC_LATEST_VER_NAME="$(printf "%s$GDC_FILE_DATA" | cut -d\/ -f3)"
    GDC_LATEST_VER="${GDC_LATEST_VER_NAME//\./}"
    printf "$GDC_LATEST_VER" | grep -Eq '^[0-9]+$'
}
gdc_get_data_installed () {
    GDC_INSTALLED_DATA="$(wmic PATH Win32_videocontroller WHERE "AdapterCompatibility='NVIDIA' AND Availability='3'" GET DriverVersion,Description /value | sed 's/\r//g;s/^M$//;/^$/d')"
    printf "%s$GDC_INSTALLED_DATA" | grep -qo "NVIDIA"
}
gdc_get_ver_installed () {
    [ "$1" = true ] && gdc_get_data_installed
    GDC_INSTALLED_VER="$(printf "%s${GDC_INSTALLED_DATA##*=}" | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')"
    GDC_INSTALLED_VER_NAME="$(printf "%s$GDC_INSTALLED_VER" | sed 's/./.&/4')"
    printf "$GDC_INSTALLED_VER" | grep -Eq '^[0-9]+$'
}
gdc_get_desc_adapter () {
    GDC_NOTEBOOK=false
    GDC_VID_DESC="$(printf "%s$GDC_INSTALLED_DATA" | awk -F\= '/NVIDIA/ {print $2}')"
    [ -z "$GDC_VID_DESC" ] && return 1
    grep -wqs "$GDC_VID_DESC" "$GDC_PATH/devices_notebook.txt" && { GDC_NOTEBOOK=true; return 0; }
    grep -wqs "$GDC_VID_DESC" "$GDC_PATH/devices_desktop.txt" || return 1
}
gdc_check_url () {
    wget -U "$GDC_WGET_USR_AGENT" --no-cookies -t 1 -T 3 -q --spider "$1"
}
gdc_get_uri_driver () {
    local url="http://us.download.nvidia.com"
    GDC_DOWNLOAD_URL="$url$GDC_FILE_DATA"
    $GDC_USE_INTL && GDC_DOWNLOAD_URL="${GDC_DOWNLOAD_URL//english/international}"
    gdc_check_url "$GDC_DOWNLOAD_URL"
}
gdc_eval_versions () {
    if [ "$GDC_INSTALLED_VER" -lt "$GDC_LATEST_VER" ]; then
        GDC_UPDATE=true; GDC_REINSTALL=false
    elif $GDC_REINSTALL && [ "$GDC_INSTALLED_VER" -eq "$GDC_LATEST_VER" ]; then
        GDC_REINSTALL=true
    elif [ "$GDC_INSTALLED_VER" -gt "$GDC_LATEST_VER" ]; then
        GDC_FAIL=true
    fi
    gdc_print_update_txt
}
gdc_print_update_txt () {
    $GDC_FAIL && gdc_log_error "Your installed Version is somehow newer than NVIDIA latest version\n"
    $GDC_REINSTALL && { printf "%sInstalled verison: $GDC_INSTALLED_VER_NAME, re-installing: $GDC_LATEST_VER_NAME\n"; return 0; }
    $GDC_UPDATE || { printf "%sAlready latest version: $GDC_INSTALLED_VER_NAME\n"; return 0; }
    $GDC_UPDATE && printf "%sNew version available"'!'"\nCurrent: $GDC_INSTALLED_VER_NAME\nLatest: $GDC_LATEST_VER_NAME\n"
}
gdc_ask_do_install () {
    local msg="Download, Extract, and Install new version"
    gdc_ask "$msg ( $GDC_LATEST_VER_NAME ) now?"
}
gdc_ask_do_reinstall () {
    gdc_ask "Are you sure you would like to re-install version: $GDC_LATEST_VER_NAME?"
}
gdc_check_valid_download  () {
    printf "%sMaking sure previously downloaded archive size is valid..."
    local lsize="$(stat -c %s "$GDC_DL_PATH/$GDC_FILE_NAME" 2>/dev/null)"
    local rsize="$(wget -U "$GDC_WGET_USR_AGENT" --no-cookies --spider -qSO- 2>&1 "$GDC_DOWNLOAD_URL" | awk '/Length/ {print $2}')"
    [ "$lsize" -eq "$rsize" ] || { printf "Failed"; sleep 2; return 1; }
    printf "Done\n"
    printf "Testing archive integrity..."
    "$GDC_S7BIN" t "$(cygpath -wa "$GDC_DL_PATH/$GDC_FILE_NAME")"
}
gdc_wget_latest_driver () {
    printf "%sDownloading latest version into \"$GDC_DL_PATH\"..."
    [ "$1" = true ] && rm -f "$GDC_DL_PATH/$GDC_FILE_NAME" || local opts='-N'
    wget -U "$GDC_WGET_USR_AGENT" --no-cookies $opts -P "$GDC_DL_PATH" "$GDC_DOWNLOAD_URL"
}
gdc_ext_7z_latest_driver () {
    printf "%sExtracting new driver archive..."
    local src="$(cygpath -wa "$GDC_DL_PATH/$GDC_FILE_NAME")"
    GDC_EXTRACT_PATH="$GDC_EXT_PATH\GDC-$GDC_LATEST_VER-$(date +%m%y%S)"
    "$GDC_S7BIN" x "$src" -o"$GDC_EXTRACT_PATH" $(printf -- '-xr!%s ' "${GDC_EXCL_PKGS[@]}") -y >/dev/null 2>&1 && printf "Done\n"
}
gdc_gen_args_installer () {
    GDC_INSTALLER_ARGS="-nofinish -passive -nosplash -noeula"
    $GDC_SILENT && GDC_INSTALLER_ARGS="${GDC_INSTALLER_ARGS} -s"
    $GDC_CLEAN_INSTALL && GDC_INSTALLER_ARGS="${GDC_INSTALLER_ARGS} -clean"
    $GDC_ATTENDED && GDC_INSTALLER_ARGS=
    $GDC_USE_REBOOT_PROMPT || GDC_INSTALLER_ARGS="${GDC_INSTALLER_ARGS} -n"
}
gdc_exec_installer () {
    gdc_gen_args_installer
    printf "%sExecuting installer setup..."
    cygstart -w --action=runas "$GDC_EXTRACT_PATH/setup.exe" "$GDC_INSTALLER_ARGS"
    local code="$?"
    printf "Done\n"
    return "$code"
}
gdc_eval_ver_installed () {
    gdc_get_data_installed
    gdc_get_ver_installed
    [ "$GDC_INSTALLED_VER" -eq "$GDC_LATEST_VER" ]
}
gdc_exec_proc_szip () {
    gdc_check_hash 7za && { GDC_S7BIN="7za"; return 0; }
    gdc_find_path_szip || gdc_wget_szip || return 1
    [ -z "$GDC_SEVEN_ZIP" ] && gdc_log_error "can't find 7-Zip installation, please install 7-Zip."
    gdc_ask "7z.exe found. Create symbolic link for 7-Zip?" || { GDC_S7BIN="$GDC_SEVEN_ZIP"; return 0; }
    local binpath="$(dirname "$(which ls)")"
    gdc_check_path "$binpath" && ln -s "$GDC_SEVEN_ZIP" "$binpath"
}
gdc_find_path_szip () {
    local pfiles="$(cd -P "$(cygpath -W)"; cd .. && pwd)/Program Files"
    local find="$(find "$pfiles" "$pfiles (x86)" -maxdepth 2 -type f -name "7z.exe" -print)"
    for i in $find; do
        [ -x "$i" ] && gdc_check_hash "$i" && { GDC_SEVEN_ZIP="$i"; return 0; }
    done
    return 1
}
gdc_exec_msi_szip () {
    local msiexec="$(cygpath -S)/msiexec.exe"
    gdc_check_file x "$msiexec" || return 1
    gdc_ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2" && local passive="/passive"
    cygstart -w --action=runas "$msiexec" $passive /norestart /i "$(cygpath -wal "$GDC_DL_PATH/7z922-x64.msi")" || return 1
}
gdc_wget_szip () {
    local url="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
    gdc_ask "Download 7-Zip v9.22 x86_64 msi package?" || return 1
    gdc_get_path_download || { printf "error getting download path, try [-d /path]"; return 1; }
    wget -U "$GDC_WGET_USR_AGENT" --no-cookies -N --no-check-certificate -P "$GDC_DL_PATH" "$url" && { gdc_exec_msi_szip || return 1; } || return 1
    gdc_find_path_szip
}
gdc_get_array_deps () {
    GDC_DEPS=('uname' 'cygpath' 'find' 'sed' 'cygstart' 'grep' 'wget' '7z' 'wmic' 'tar' 'gzip' 'logger')
}
gdc_check_deps () {
    gdc_get_array_deps
    for dep in "${GDC_DEPS[@]}"; do
        case "$dep" in
             wmic) gdc_check_hash wmic || PATH="${PATH}:$(cygpath -S)/Wbem"; gdc_check_hash wmic || gdc_log_error "adding wmic to PATH" ;;
               7z) gdc_check_hash 7z && GDC_S7BIN="7z" || { gdc_exec_proc_szip || gdc_log_error "Dependency not found :: 7z (7-Zip)"; } ;;
                *) gdc_check_hash "$dep" || gdc_log_error "Dependency not found :: $dep" ;;
        esac
    done
}
gdc_get_options "$@" && shift $((OPTIND-1))
gdc_check_deps
gdc_check_cygwin || gdc_log_error "Cygwin not detected :: $(uname -o)"
gdc_check_ver_os || gdc_log_error "Unsupported OS Version = $(check_ver_os true)"
gdc_check_arch_win || gdc_log_error "Unsupported architecture = $(check_arch_win true)"
gdc_get_data_installed || gdc_log_error "did not find NVIDIA graphics adapter"
gdc_get_path_gdc || gdc_log_error "validating scripts execution path :: $GDC_PATH"
gdc_get_path_root || gdc_log_error "validating root path :: $GDC_ROOT_PATH"
gdc_get_path_download || gdc_log_error "validating download path :: $GDC_DL_PATH"
gdc_ext_tar_devices || gdc_log_error "validating devices dbase :: $GDC_PATH/devices_notebook.txt"
gdc_get_desc_adapter || gdc_log_error "not Geforce drivers compatabile adapter :: $GDC_VID_DESC"
gdc_get_data_net || gdc_log_error "in online data query :: $GDC_FILE_DATA"
gdc_get_ver_latest || gdc_log_error "invalid driver version string :: $GDC_LATEST_VER"
gdc_get_ver_installed || gdc_log_error "invalid driver version string :: $GDC_INSTALLED_VER"
gdc_eval_versions
$GDC_CHECK_ONLY && { $GDC_UPDATE && exit 0 || exit 1; }
$GDC_UPDATE || $GDC_REINSTALL || exit 0
gdc_get_filename_latest || gdc_log_error "invalid file name returned :: $GDC_FILE_NAME"
gdc_get_uri_driver || gdc_log_error "validating driver download uri :: $GDC_DOWNLOAD_URL"
if $GDC_REINSTALL; then
    gdc_ask_do_reinstall || gdc_log_error "User cancelled"
    gdc_check_file "$GDC_DL_PATH/$GDC_FILE_NAME"
    gdc_check_valid_download || gdc_wget_latest_driver true || gdc_log_error "wget downloading file :: $GDC_DOWNLOAD_URL"
elif $GDC_UPDATE; then
    gdc_ask_do_install || gdc_log_error "User cancelled"
    gdc_wget_latest_driver || gdc_log_error "wget downloading file :: $GDC_DOWNLOAD_URL"
fi
gdc_check_mkdir "$GDC_ROOT_PATH/NVIDIA" || gdc_log_error "creating path :: $GDC_ROOT_PATH/NVIDIA"
gdc_ext_7z_latest_driver || gdc_log_error "extracting new driver archive :: $GDC_EXT_PATH"
gdc_exec_installer || gdc_log_error "Installation failed or user interupted"
gdc_get_ver_installed true || gdc_log_error "invalid driver version string :: $GDC_INSTALLED_VER"
gdc_eval_ver_installed || gdc_log_error "After all that your driver version didn't change!"
printf "Driver update successfull!"
exit 0
