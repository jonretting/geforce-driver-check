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
gdc_version="1.082"

# cutomizable defaults (respects environment defined vars) inline cmd over-rides both
gdc_dl_path="${gdc_dl_path:=}"  # download path ex: gdc_dl_path="${gdc_dl_path:=/this/download/path}"
gdc_ext_path="${gdc_ext_path:-$SYSTEMDRIVE\NVIDIA}" # extract driver file here use WIN/DOS path
gdc_use_intl="${gdc_use_intl:-false}" # use international driver package version multi language support
gdc_wget_usr_agent="${gdc_wget_usr_agent:-Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0}"    # agent passed to wget

# remove these nvidia packages from driver install
gdc_excl_pkgs=("GFExperience*" "NV3DVision*" "Display.Update" "Display.Optimus" "Display.NView" "Network.Service" "MS.NET" "ShadowPlay" "LEDVisualizer" "NvVAD")

__print_usage () {
    printf "%s\n Geforce Driver Check $gdc_version
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
__get_options () {
    __get_defaults
    local opts="asyd:cRVCAirh"
    while getopts "$opts" gdc_options; do
        case "$gdc_options" in
            a) gdc_attended=true ;;
            s) gdc_silent=true ;;
            y) gdc_yestoall=true ;;
            d) gdc_dl_path="$OPTARG" ;;
            c) gdc_clean_install=true ;;
            R) gdc_reinstall=true ;;
            V) printf "%sVersion $gdc_version\n"; exit 0 ;;
            C) gdc_check_only=true ;;
            A) gdc_attended=true; gdc_excl_pkgs=;;
            i) gdc_use_intl=true ;;
            r) gdc_use_reboot_prompt=true ;;
            h) __print_usage; exit 0 ;;
            *) __print_usage; exit 1 ;;
        esac
    done
}
__get_defaults () {
    gdc_silent=false
    gdc_yestoall=false
    gdc_check_only=false
    gdc_attended=false
    gdc_clean_install=false
    gdc_reinstall=false
    gdc_use_reboot_prompt=false
    gdc_update=false
    gdc_fail=false
    gdc_script_path="$0"
}
__ask () {
    while true; do
        [ "$2" ] && { local pmt="$2";local def=""; }; [ "$2" ] || { local pmt="y/n";local def=""; }
        $gdc_yestoall && { local rpy="Y";local def="Y"; }; [ -z "$def" ] && { printf "%s$1 [$pmt] ";read rpy; }
        [ -z "$rpy" ] && local rpy="$def"; case "$rpy" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
    done
}
__log_error () {
    printf "%s$(date): Error: geforce.sh : $1" | tee -a /var/log/messages
    exit 1
}
__check_hash () {
    hash "$1" 2>/dev/null
}
__check_file () {
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
__check_files () {
    local files="$2"; local opts="$1"
    for file in $files; do
        __check_file "$opts" "$file" || return 1
    done
}
__check_path () {
    __check_file dr "$1"
}
__check_mkdir () {
    __check_path "$1" || { mkdir -p "$1" || __log_error "error creating folder paths"; }
}
__check_cygwin () {
    [ "$(uname -o)" = "Cygwin" ]
}
__check_ver_os () {
    [ "$1" = true ] && { wmic os get version /value | grep -Eo '[^=]*$'; return $?; }
    wmic os get version /value | grep -Eq '6\.[1-3]{1}.*'
}
__check_arch_win () {
    [ "$1" = true ] && { wmic OS get OSArchitecture /value | grep -Eo '[^=]*$'; return $?; }
    wmic OS get OSArchitecture /value | grep -q '64-bit'
}
__ext_tar_devices () {
    __check_files rs "$gdc_path/devices_notebook.txt $gdc_path/devices_desktop.txt" && return 0
    tar xf "$gdc_path/devices_dbase.tar.gz" -C "$gdc_path"
    __check_files rs "$gdc_path/devices_notebook.txt $gdc_path/devices_desktop.txt"
}
__get_path_gdc () {
    local src="$gdc_script_path"
    while [ -h "$src" ]; do
        local dir="$(cd -P "$(dirname "$src")" && pwd)"
        local src="$(readlink "$src")"
        [ "$src" != /* ] && local src="$dir/$src"
        local c=$((c+1)); [ "$c" -gt 3 ] && return 1
    done
    gdc_path="$(cd -P "$(dirname "$src")" && pwd)"
    __check_path "$gdc_path"
}
__get_path_root () {
    [ -n "$SYSTEMDRIVE" ] && gdc_root_path="$(cygpath "$SYSTEMDRIVE")"
    __check_path "$gdc_root_path" && return 0
    gdc_root_path="$(cd -P "$(cygpath -W)" && { cd .. && pwd; } || return 1)"
    __check_path "$gdc_root_path" && return 0
    gdc_root_path="$(which explorer.exe | sed 's/.Windows\/explorer\.exe//')"
    __check_path "$gdc_root_path"
}
__get_path_download () {
    [ -n "$SYSTEMDRIVE" ] && __check_path "$gdc_dl_path" && return 0
    gdc_dl_path="$(cygpath -O | sed 's/Documents/Downloads/')"
    __check_path "$gdc_dl_path" && return 0
    gdc_dl_path="$gdc_ext_path/Downloads"
    __check_mkdir "$gdc_dl_path" && return 0
    gdc_dl_path="$(cd -P "$(cygpath -O)" && { cd ../Downloads && pwd; } || return 1)"
    __check_path "$gdc_dl_path"
}
__get_wget () {
    wget -U "$gdc_wget_usr_agent" --no-cookies -qO- 2>/dev/null "$1"
}   
__get_data_net () {
    local desktop_id="95"
    local notebook_id="92"
    local link="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
    $gdc_notebook && local link+="$notebook_id" || local link+="$desktop_id"
    local link="$(__get_wget "$link" | awk '/driverResults.aspx/ {print $4}' | awk -F\' 'NR==1 {print $2}')"
    gdc_file_data="$(__get_wget "$link" | awk 'BEGIN {FS="="} /url=/ {gsub("&lang","");print $3}')"
    printf "$gdc_file_data" | grep -Eq "/Windows/.*\.exe"
}
__get_filename_latest () {
    gdc_file_name="${gdc_file_data##/*/}"
    $gdc_use_intl && gdc_file_name="$(printf "$gdc_file_name" | sed 's/english/international/')"
    printf "$gdc_file_name" | grep -Eq "^$gdc_latest_ver_name\-.*\.exe$" 
}
__get_ver_latest () {
    gdc_latest_ver_name="$(printf "%s$gdc_file_data" | cut -d\/ -f3)"
    gdc_latest_ver="$(printf "$gdc_latest_ver_name" | sed 's/\.//g')"
    printf "$gdc_latest_ver" | grep -Eq '^[0-9]{5}$'
}
__get_data_installed () {
    gdc_installed_data="$(wmic PATH Win32_videocontroller WHERE "AdapterCompatibility='NVIDIA' AND Availability='3'" GET DriverVersion,Description /value | sed 's/\r//g;s/^M$//;/^$/d')"
    printf "%s$gdc_installed_data" | grep -qo "NVIDIA"
}
__get_ver_installed () {
    [ "$1" = true ] && __get_data_installed
    gdc_installed_ver="$(printf "%s${gdc_installed_data##*=}" | sed 's/\.//g;s/^.*\(.\{5\}\)$/\1/')"
    gdc_installed_ver_name="$(printf "%s$gdc_installed_ver" | sed 's/./.&/4')"
    printf "$gdc_installed_ver" | grep -Eq '^[0-9]+$'
}
__get_desc_adapter () {
    gdc_notebook=false
    gdc_vid_desc="$(printf "%s$gdc_installed_data" | awk -F\= '/NVIDIA/ {print $2}')"
    [ -z "$gdc_vid_desc" ] && return 1
    grep -wqs "$gdc_vid_desc" "$gdc_path/devices_notebook.txt" && { gdc_notebook=true; return 0; }
    grep -wqs "$gdc_vid_desc" "$gdc_path/devices_desktop.txt" || return 1
}
__check_url () {
    wget -U "$gdc_wget_usr_agent" --no-cookies -t 1 -T 3 -q --spider "$1"
}
__get_uri_driver () {
    local url="http://us.download.nvidia.com"
    gdc_download_url="$url$gdc_file_data"
    $gdc_use_intl && gdc_download_url="$(printf "$gdc_download_url" | sed 's/english/international')"
    __check_url "$gdc_download_url"
}
__eval_versions () {
    if [ "$gdc_installed_ver" -lt "$gdc_latest_ver" ]; then
        gdc_update=true; gdc_reinstall=false
    elif $gdc_reinstall && [ "$gdc_installed_ver" -eq "$gdc_latest_ver" ]; then
        gdc_reinstall=true
    elif [ "$gdc_installed_ver" -gt "$gdc_latest_ver" ]; then
        gdc_fail=true
    fi
    __print_update_txt
}
__print_update_txt () {
    $gdc_fail && __log_error "Your installed Version is somehow newer than NVIDIA latest version\n"
    $gdc_reinstall && { printf "%sInstalled verison: $gdc_installed_ver_name, re-installing: $gdc_latest_ver_name\n"; return 0; }
    $gdc_update || { printf "%sAlready latest version: $gdc_installed_ver_name\n"; return 0; }
    $gdc_update && printf "%sNew version available"'!'"\nCurrent: $gdc_installed_ver_name\nLatest: $gdc_latest_ver_name\n"
}
__ask_do_install () {
    local msg="Download, Extract, and Install new version"
    __ask "$msg ( $gdc_latest_ver_name ) now?"
}
__ask_do_reinstall () {
    __ask "Are you sure you would like to re-install version: $gdc_latest_ver_name?"
}
__check_valid_download  () {
    printf "%sMaking sure previously downloaded archive size is valid..."
    local lsize="$(stat -c %s "$gdc_dl_path/$gdc_file_name" 2>/dev/null)"
    local rsize="$(wget -U "$gdc_wget_usr_agent" --no-cookies --spider -qSO- 2>&1 "$gdc_download_url" | awk '/Length/ {print $2}')"
    [ "$lsize" -eq "$rsize" ] || { printf "Failed"; sleep 2; return 1; }
    printf "Done\n"
    printf "Testing archive integrity..."
    "$gdc_s7bin" t "$(cygpath -wa "$gdc_dl_path/$gdc_file_name")"
}
__wget_latest_driver () {
    printf "%sDownloading latest version into \"$gdc_dl_path\"..."
    [ "$1" = true ] && rm -f "$gdc_dl_path/$gdc_file_name" || local opts='-N'
    wget -U "$gdc_wget_usr_agent" --no-cookies $opts -P "$gdc_dl_path" "$gdc_download_url"
}
__ext_7z_latest_driver () {
    printf "%sExtracting new driver archive..."
    local src="$(cygpath -wa "$gdc_dl_path/$gdc_file_name")"
    gdc_ext_path="$gdc_ext_path\GDC-$gdc_latest_ver-$(date +%m%y%S)"
    "$gdc_s7bin" x "$src" -o"$gdc_ext_path" $(printf -- '-xr!%s ' "${gdc_excl_pkgs[@]}") -y >/dev/null 2>&1 && printf "Done\n"
}
__gen_args_installer () {
    gdc_installer_args="-nofinish -passive -nosplash -noeula"
    $gdc_silent && gdc_installer_args="${gdc_installer_args} -s"
    $gdc_clean_install && gdc_installer_args="${gdc_installer_args} -clean"
    $gdc_attended && gdc_installer_args=
    $gdc_use_reboot_prompt || gdc_installer_args="${gdc_installer_args} -n"
}
__exec_installer () {
    __gen_args_installer
    printf "%sExecuting installer setup..."
    cygstart -w --action=runas "$gdc_ext_path/setup.exe" "$gdc_installer_args"
    local code="$?"
    printf "Done\n"
    return "$code"
}
__eval_ver_installed () {
    __get_data_installed
    __get_ver_installed
    [ "$gdc_installed_ver" -eq "$gdc_latest_ver" ]
}
__exec_proc_szip () {
    __check_hash 7za && { gdc_s7bin="7za"; return 0; }
    __find_path_szip || __wget_szip || return 1
    [ -z "$gdc_seven_zip" ] && __log_error "can't find 7-Zip installation, please install 7-Zip."
    __ask "7z.exe found. Create symbolic link for 7-Zip?" || { gdc_s7bin="$gdc_seven_zip"; return 0; }
    local binpath="$(dirname "$(which ls)")"
    __check_path "$binpath" && ln -s "$gdc_seven_zip" "$binpath"
}
__find_path_szip () {
    local pfiles="$(cd -P "$(cygpath -W)"; cd .. && pwd)/Program Files"
    local find="$(find "$pfiles" "$pfiles (x86)" -maxdepth 2 -type f -name "7z.exe" -print)"
    for i in $find; do
        [ -x "$i" ] && __check_hash "$i" && { gdc_seven_zip="$i"; return 0; }
    done
    return 1
}
__exec_msi_szip () {
    local msiexec="$(cygpath -S)/msiexec.exe"
    __check_file x "$msiexec" || return 1
    __ask "1) Unattended 7-Zip install 2) Launch 7-Zip Installer" "1/2" && local passive="/passive"
    cygstart -w --action=runas "$msiexec" $passive /norestart /i "$(cygpath -wal "$gdc_dl_path/7z922-x64.msi")" || return 1
}
__wget_szip () {
    local url="https://downloads.sourceforge.net/project/sevenzip/7-Zip/9.22/7z922-x64.msi"
    __ask "Download 7-Zip v9.22 x86_64 msi package?" || return 1
    __get_path_download || { printf "error getting download path, try [-d /path]"; return 1; }
    wget -U "$gdc_wget_usr_agent" --no-cookies -N --no-check-certificate -P "$gdc_dl_path" "$url" && { __exec_msi_szip || return 1; } || return 1
    __find_path_szip
}
__get_array_deps () {
    gdc_deps=('uname' 'cygpath' 'find' 'sed' 'cygstart' 'grep' 'wget' '7z' 'wmic' 'tar' 'gzip' 'logger')
}
__check_deps () {
    __get_array_deps
    for dep in "${gdc_deps[@]}"; do
        case "$dep" in
             wmic) __check_hash wmic || PATH="${PATH}:$(cygpath -S)/Wbem"; __check_hash wmic || __log_error "adding wmic to PATH" ;;
               7z) __check_hash 7z && gdc_s7bin="7z" || { __exec_proc_szip || __log_error "Dependency not found :: 7z (7-Zip)"; } ;;
                *) __check_hash "$dep" || __log_error "Dependency not found :: $dep" ;;
        esac
    done
}
__get_options "$@" && shift $((OPTIND-1))
__check_deps
__check_cygwin || __log_error "Cygwin not detected :: $(uname -o)"
__check_ver_os || __log_error "Unsupported OS Version = $(check_ver_os true)"
__check_arch_win || __log_error "Unsupported architecture = $(check_arch_win true)"
__get_data_installed || __log_error "did not find NVIDIA graphics adapter"
__get_path_gdc || __log_error "validating scripts execution path :: $gdc_path"
__get_path_root || __log_error "validating root path :: $gdc_root_path"
__get_path_download || __log_error "validating download path :: $gdc_dl_path"
__ext_tar_devices || __log_error "validating devices dbase :: $gdc_path/devices_notebook.txt"
__get_desc_adapter || __log_error "not Geforce drivers compatabile adapter :: $gdc_vid_desc"
__get_data_net || __log_error "in online data query :: $gdc_file_data"
__get_ver_latest || __log_error "invalid driver version string :: $gdc_latest_ver"
__get_ver_installed || __log_error "invalid driver version string :: $gdc_installed_ver"
__eval_versions
$gdc_check_only && { $gdc_update && exit 0 || exit 1; }
$gdc_update || $gdc_reinstall || exit 0
__get_filename_latest || __log_error "invalid file name returned :: $gdc_file_name"
__get_uri_driver || __log_error "validating driver download uri :: $gdc_download_url"
if $gdc_reinstall; then
    __ask_do_reinstall || __log_error "User cancelled"
    __check_file "$gdc_dl_path/$gdc_file_name"
    __check_valid_download || __wget_latest_driver true || __log_error "wget downloading file :: $gdc_download_url"
elif $gdc_update; then
    __ask_do_install || __log_error "User cancelled"
    __wget_latest_driver || __log_error "wget downloading file :: $gdc_download_url"
fi
__check_mkdir "$gdc_root_path/NVIDIA" || __log_error "creating path :: $gdc_root_path/NVIDIA"
__ext_7z_latest_driver || __log_error "extracting new driver archive :: $gdc_ext_path"
__exec_installer || __log_error "Installation failed or user interupted"
__get_ver_installed true || __log_error "invalid driver version string :: $gdc_installed_ver"
__eval_ver_installed || __log_error "After all that your driver version didn't change!"
printf "Driver update successfull!"
exit 0
