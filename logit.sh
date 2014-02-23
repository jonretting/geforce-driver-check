#!/bin/bash
# this generates a log.cmd file to retrun correct exit codes
# in windows, and write a standard windows event with the proper info
# then exits the log.cmd temp file, then deletes the file
# *defaults to APPLICATION log*
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

usage () {
	echo " usage: logit.sh [-h] [-e] [-i=n] [-s] <description>
 example: logit.sh -e 1 -i 501 -s myscript.sh \"failed to run the mount command\"
 -e    Priority: 0 | success | SUCCESS | true   == SUCCESS
                 1 | error   | ERROR   | false  == ERROR
                 2 | warn    | WARN |  == WARNING
                 3 | info    | INFO |  == INFORMATION
 -i    Event ID: exit error code number
 -s    Source File: the script which returned the error exit code
 -h    This cruft"
}
get-options () {
	local opts="e:i:s:"
	while getopts "$opts" OPTIONS; do
		case "${OPTIONS}" in
			e) PRIORITY=$(get-priority-level "${OPTARG}") ;;
            i) ID="${OPTARG}" ;;
			s) SOURCE="${OPTARG}" ;;
			h) usage; exit 0 ;;
			*) usage; exit 1 ;;
		esac
	done
}
get-priority-level () {
	local arg="$1"
	case "$arg" in
       0|success|SUCCESS|true) echo "SUCCESS" ;;
          1|error|ERROR|false) echo "ERROR" ;;
                  2|warn|WARN) echo "WARNING" ;;
                  3|info|INFO) echo "INFORMATION" ;;
                            *) return 1 ;;
	esac
}
get-desc () {
	[[ -z "$1" ]] && return 1
	DESC="$1"
	return 0
}
create-event () {
	local cmd="eventcreate /ID $ID /L Application /SO $SOURCE /T $PRIORITY /D "
	if [[ "$1" == *';'* ]]; then
		local IFS=';'
		for i in "$1"; do
			$cmd "$i" &>/dev/null
		done
	else
		$cmd "$DESC" &>/dev/null
	fi
}

get-options "$@" && shift $(($OPTIND-1))

get-desc "$@" || { echo "Error no description given"; exit 1; }

cat<<EOF>${TEMP}/eventcreate.tmp.cmd
@echo off
set EXITCODE="$ID"
exit /b %EXITCODE%
EOF

unix2dos "${TEMP}/eventcreate.tmp.cmd" &>/dev/null

cmd /c "%TEMP%\eventcreate.tmp.cmd"

create-event

rm "${TEMP}/eventcreate.tmp.cmd"

exit 0
