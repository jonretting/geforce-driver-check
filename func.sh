# This file is sourced by geforce.sh and should not include a shebang
#
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

# begin GDC functions

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
 -F    Force running installer even if no NVIDIA card detects (New Installs)
 -r    Don't disable reboot prompt when reboot is needed
 -V    Displays version info
 -h    this crupt\n"
}
__get_options () {
    __get_defaults
    local opts="asyd:cRVCAirhF"
    while getopts "$opts" gdc_options; do
        case "$gdc_options" in
            a) gdc_attended=true ;;
            s) gdc_silent=true ;;
            F) gdc_force_install=true ;;
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
    gdc_force_install=false
}
__ask () {
    while true; do
        [ "$2" ] && { local pmt="$2";local def=""; }; [ "$2" ] || { local pmt="y/n";local def=""; }
        $gdc_yestoall && { local rpy="Y";local def="Y"; }; [ -z "$def" ] && { printf "%s$1 [$pmt] ";read rpy; }
        [ -z "$rpy" ] && local rpy="$def"; case "$rpy" in Y*|y*) return 0;; N*|n*) return 1;;1*) return 0;;2*) return 1;;esac
    done
}
__fix_oldsymlinks () {
    which geforce && __get_symlinks
}
__get_symlinks () {
    which geforce
}
__log_error () {
    printf "%s$(date): Error: geforce.sh : $1" | tee -a /var/log/messages
    exit 1
}
__get_cache () {
    __check_file rw "$gdc_cache" || { >"$gdc_cache" || __log_error "reading cache file :: $gdc_cache"; }
    __load_cache || return 1
}
__check_var () {
    if [ -n "$1" ] && [ -n "$2" ]; then
        [ "$1" = "$2" ] && return 0 || return 1
    fi
    [ -n "$1" ]
}
__write_cache () {
    __rm_cache "$1"
    printf "%s$1=\"$2\"\n" >> "$gdc_cache" || __log_error "writing cache file :: $gdc_cache"
    $3 && __check_cache "$1" "$2"
}
__check_cache () {
        if __check_var "$1" "$2"; then
            "$gdc_grep" "$1" "$gdc_cache" | "$gdc_grep" -q "$2" && return 0 || return 1
        else
            "$gdc_grep" "$1" "$gdc_cache" | "$gdc_grep" -q "$2" || __load_cache
            __check_var "$1" "$2" && return 0 || return 1
        fi
    if [ -z "$2" ]; then
        if __check_var "$1"; then
            "$gdc_grep" "$1" "$gdc_cache" && return 1
        else
            "$gdc_grep" "$1" "$gdc_cache" || __load_cache
            __check_var "$1" && return 1
        fi
    fi
    return 0
}
__rm_cache () {
    #hash $gdc_sed >/dev/null 2>&1 || gdc_sed="$gdc_path/bin/sed.exe"
    ${gdc_sed} -i 's/\('"$1"'=\).*/\1/g' "$gdc_cache"
    __load_cache || return 1
}
__clear_cache () {
    "$gdc_sed" -i 's/\(.*\=\).*/\1/g' "$gdc_cache"
    __load_cache || return 1
    >"$gdc_cache" || __log_error "error crearing cache file :: $gdc_cache"
}
__load_cache () {
    . "$gdc_cache" || __log_error "sourcing cache file :: $gdc_cache"
}
__check_file () {
    while [ ${#} -gt 0 ]; do
        case "$1" in
            x) [ -x "$2" ] || return 1 ;;
           rw) [ -r "$2" ] && [ -w "$2" ] || return 1 ;;
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
    [ "$("$gdc_uname" -o)" = "Cygwin" ]
}
__check_ver_os () {
    [ "$1" = true ] && { wmic os get version /value | "$gdc_grep" -Eo '[^=]*$'; return $?; }
    wmic os get version /value | "$gdc_grep" -Eq '6\.[1-3]{1}.*'
}
__check_arch_win () {
    [ "$1" = true ] && { wmic OS get OSArchitecture /value | "$gdc_grep" -Eo '[^=]*$'; return $?; }
    wmic OS get OSArchitecture /value | "$gdc_grep" -q '64-bit'
}
__ext_tar_devices () {
    __check_files rs "$gdc_path/devices_notebook.txt $gdc_path/devices_desktop.txt" && return 0
    "$gdc_tar" -xf "$gdc_path/devices_dbase.tar.xz" -C "$gdc_path"
    __check_files rs "$gdc_path/devices_notebook.txt $gdc_path/devices_desktop.txt"
}
__get_path_root () {
    [ -n "$SYSTEMDRIVE" ] && gdc_root_path="$("$gdc_cygpath" "$SYSTEMDRIVE")"
    __check_path "$gdc_root_path" && return 0
    gdc_root_path="$(cd -P "$("$gdc_cygpath" -W)" && { cd .. && pwd; } || return 1)"
    __check_path "$gdc_root_path" && return 0
    gdc_root_path="$(which explorer.exe | "$gdc_sed" 's/.Windows\/explorer\.exe//')"
    __check_path "$gdc_root_path"
}
__get_path_download () {
    [ -n "$SYSTEMDRIVE" ] && __check_path "$gdc_dl_path" && return 0
    gdc_dl_path="$("$gdc_cygpath" -O | "$gdc_sed" 's/Documents/Downloads/')"
    __check_path "$gdc_dl_path" && return 0
    gdc_dl_path="$gdc_ext_path/Downloads"
    __check_mkdir "$gdc_dl_path" && return 0
    gdc_dl_path="$(cd -P "$("$gdc_cygpath" -O)" && { cd ../Downloads && pwd; } || return 1)"
    __check_path "$gdc_dl_path"
}
__get_wget () {
    "$gdc_wget" -U "$gdc_wget_usr_agent" --no-cookies -qO- 2>/dev/null "$1"
}   
__get_data_net () {
    local desktop_id="95"
    local notebook_id="92"
    local link="http://www.nvidia.com/Download/processFind.aspx?osid=19&lid=1&lang=en-us&psid="
    $gdc_notebook && local link+="$notebook_id" || local link+="$desktop_id"
    local link="$(__get_wget "$link" | "$gdc_awk" '/driverResults.aspx/ {print $4}' | "$gdc_awk" -F\' 'NR==1 {print $2}')"
    gdc_file_data="$(__get_wget "$link" | "$gdc_awk" 'BEGIN {FS="="} /url=/ {gsub("&lang","");print $3}')"
    printf "$gdc_file_data" | "$gdc_grep" -Eq "/Windows/.*\.exe"
}
__get_filename_latest () {
    gdc_file_name="${gdc_file_data##/*/}"
    $gdc_use_intl && gdc_file_name="$(printf "$gdc_file_name" | "$gdc_sed" 's/english/international/')"
    printf "$gdc_file_name" | "$gdc_grep" -Eq "^$gdc_latest_ver_name\-.*\.exe$" 
}
__get_ver_latest () {
    gdc_latest_ver_name="$(printf "%s$gdc_file_data" | "$gdc_awk" -F\/ '{print $3}')"
    gdc_latest_ver="$(printf "$gdc_latest_ver_name" | "$gdc_sed" 's/\.//g')"
    printf "$gdc_latest_ver" | "$gdc_grep" -Eq '^[0-9]{5}$'
}
__get_data_installed () {
    $gdc_force_install && return 0
    gdc_installed_data="$(wmic PATH Win32_videocontroller WHERE "AdapterCompatibility='NVIDIA' AND Availability='3'" GET DriverVersion,Description /value | "$gdc_sed" 's/\r//g;s/^M$//;/^$/d')"
    printf "%s$gdc_installed_data" | "$gdc_grep" -qo "NVIDIA"
}
__get_ver_installed () {
    [ "$1" = true ] && __get_data_installed
    gdc_installed_ver="$(printf "%s${gdc_installed_data##*=}" | "$gdc_sed" 's/\.//g;s/^.*\(.\{5\}\)$/\1/')"
    gdc_installed_ver_name="$(printf "%s$gdc_installed_ver" | "$gdc_sed" 's/./.&/4')"
    $gdc_force_install && return 0
    printf "$gdc_installed_ver" | "$gdc_grep" -Eq '^[0-9]+$'
}
__get_desc_adapter () {
    gdc_notebook=false
    gdc_vid_desc="$(printf "%s$gdc_installed_data" | "$gdc_awk" -F\= '/NVIDIA/ {print $2}')"
    $gdc_force_install && return 0
    [ -z "$gdc_vid_desc" ] && return 1
    "$gdc_grep" -wqs "$gdc_vid_desc" "$gdc_path/devices_notebook.txt" && { gdc_notebook=true; return 0; }
    "$gdc_grep" -wqs "$gdc_vid_desc" "$gdc_path/devices_desktop.txt" || return 1
}
__check_url () {
    "$gdc_wget" -U "$gdc_wget_usr_agent" --no-cookies -t 1 -T 3 -q --spider "$1"
}
__get_uri_driver () {
    local url="http://us.download.nvidia.com"
    gdc_download_url="$url$gdc_file_data"
    $gdc_use_intl && gdc_download_url="$(printf "$gdc_download_url" | "$gdc_sed" 's/english/international')"
    __check_url "$gdc_download_url"
}
__eval_versions () {
    $gdc_force_install && { gdc_update=true; return 0; }
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
    local rsize="$("$gdc_wget" -U "$gdc_wget_usr_agent" --no-cookies --spider -qSO- 2>&1 "$gdc_download_url" | "$gdc_awk" '/Length/ {print $2}')"
    [ "$lsize" -eq "$rsize" ] || { printf "Failed"; sleep 2; return 1; }
    printf "Done\n"
    printf "Testing archive integrity..."
    "$gdc_7za" t "$("$gdc_cygpath" -wa "$gdc_dl_path/$gdc_file_name")"
}
__wget_latest_driver () {
    printf "%sDownloading latest version into \"$gdc_dl_path\"..."
    [ "$1" = true ] && rm -f "$gdc_dl_path/$gdc_file_name" || local opts='-N'
    "$gdc_wget" -U "$gdc_wget_usr_agent" --no-cookies $opts -P "$gdc_dl_path" "$gdc_download_url"
}
__ext_7z_latest_driver () {
    printf "%sExtracting new driver archive..."
    local src="$("$gdc_cygpath" -wa "$gdc_dl_path/$gdc_file_name")"
    gdc_ext_path="$gdc_ext_path\GDC-$gdc_latest_ver-$(date +%m%y%S)"
    "$gdc_7za"  x "$src" -o"$gdc_ext_path" $(printf -- '-xr!%s ' $gdc_excl_pkgs) -y >/dev/null 2>&1 && printf "Done\n"
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
    "$gdc_cygstart" -w --action=runas "$gdc_ext_path/setup.exe" "$gdc_installer_args"
    local code="$?"
    printf "Done\n"
    return "$code"
}
__eval_ver_installed () {
    __get_data_installed
    __get_ver_installed
    [ "$gdc_installed_ver" -eq "$gdc_latest_ver" ]
}
__ext_deps () {
    $gdc_cache_enable && __load_cache
    [ -e "$gdc_path/dep_binaries.tar.xz" ] || __log_error "missing \"$gdc_path/dep_binaries.tar.xz\""
    "$gdc_tar" -C "$gdc_path" -xf "$gdc_path/dep_binaries.tar.xz" $@ || return 1
}
__add_dep () {
    if $gdc_cache_enable; then
        __check_cache "$1" "$2" && return 0
        __write_cache "$1" "$2" false
    fi
    [ -n "$gdc_binlist" ] && gdc_binlist="bin/$2.exe" || gdc_binlist="$gdc_binlist bin/$2.exe"
}
__check_cmd () {
    [ "$3" = true ] && return 1
    [ "$1" = "grep" ] && gdc_grep="grep"
    [ "$1" = "sed" ] && gdc_sed="sed"
    if $gdc_cache_enable; then
        if [ "$2" = false ]; then
            if command -v "$1" >/dev/null 2>&1; then
                [ "$1" = "grep" ] && gdc_grep="grep"
                [ "$1" = "sed" ] && gdc_sed="sed"
                __check_cache "$1" || __write_cache gdc_$1 $gdc_$1
                return 0
            else
                return 1
            fi
        fi
        __check_cache "$1" && return 0
        __write_cache "$1" "$2" && return 0
        local cmd="$2"
    fi
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}
__check_deps () {
    local deps="tar grep sed wmic uname cygpath cygstart wget 7za awk"
    local dbg=false #debug
    local gdc_path="$gdc_path/bin"
    __check_cmd grep || { gdc_grep="$gdc_path/grep.exe"; __write_cache gdc_grep $gdc_grep; }
    __check_cmd sed || { gdc_sed="$gdc_path/sed.exe"; __write_cache gdc_sed $gdc_sed; }
    for dep in $deps; do
        local gdc_dep="$gdc_path/$dep.exe"
        case "$dep" in
             tar)  gdc_tar="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_tar="$gdc_dep"; };;
           uname)  gdc_uname="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_uname="$gdc_dep"; };;
         cygpath)  gdc_cygpath="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_cygpath="$gdc_dep"; };;
        cygstart)  gdc_cygstart="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_cygstart="$gdc_dep"; };;
            wget)  gdc_wget="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_wget="$gdc_dep"; };;
             7za)  gdc_7za="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_7za="$gdc_dep"; };;
             awk)  gdc_awk="$dep"; __check_cmd gdc_$dep $dep $dbg || { __add_dep gdc_$dep $gdc_dep; gdc_awk="$gdc_dep"; };;
            wmic)  __check_cmd wmic || { PATH="${PATH}:$("$gdc_cygpath" -S)/Wbem"
                        __check_cmd wmic || __log_error "adding wmic to PATH"; }
               ;;
               #*)  __check_cmd "$dep" || __log_error "Dependency not found :: $dep" ;;
        esac
        [ -n "$gdc_deplist" ] && { __ext_deps "$gdc_binlist" || __log_error "Error extracting binary dependencies"; }
    done
}
