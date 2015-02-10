#!/usr/bin/env sh
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
gdc_version="1.0922"

# determines absolute parent path of geforce.sh execution
# allows use of symlink/alias/function geforce.sh execution
__get_path_gdc () {
    local src="$0"
    while [ -h "$src" ]; do
        local dir="$(cd -P "$(dirname "$src")" && pwd)"
        local src="$(readlink "$src")"
        [ "$src" != /* ] && local src="$dir/$src"
        local c=$((c+1)); [ "$c" -gt 3 ] && return 1
    done
    gdc_path="$(cd -P "$(dirname "$src")" && pwd)"
    [ -x "$gdc_path/geforce.sh" ] && [ -r "$gdc_path" ] || return 1
}

# determine the absolute parent path to geforce.sh
__get_path_gdc || printf "Error determining GDC path\n"

# source in functions and user configurable options
. "$gdc_path/func.sh"
. "$gdc_path/config.conf"

# process command line options/arguements
__get_options "$@" && shift $((OPTIND-1))

# validate script dependencies, dies inside using __log_error
__check_deps

# validate cygwin installation
__check_cygwin || __log_error "Cygwin not detected :: $(uname -o)"

# validate compatable Windows version >6.1
__check_ver_os || __log_error "Unsupported OS Version = $(check_ver_os true)"

# validate Windows architecture as x86_64 using wmic
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
$gdc_rm_old_drivers && __rm_old_drivers
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
__check_file x "$gdc_ext_path/setup.exe" || { chmod -R +x "$gdc_ext_path" || __log_error "Applying permssions to downloaded path :: $gdc_ext_path"; }
__exec_installer || __log_error "Installation failed or user interupted"
__get_ver_installed true || __log_error "invalid driver version string :: $gdc_installed_ver"
__eval_ver_installed || __log_error "After all that your driver version didn't change!"
printf "Driver update successfull!"
exit 0
