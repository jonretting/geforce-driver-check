#!/usr/bin/env bash
# Generates a log.cmd tmp file to retrun correct exit codes
# in windows, and write a standard windows event with the proper info
# then exits the log.cmd temp file, then deletes temp file
# also generate standard logger entry and stdout the error
# todo: respect any quit switch passed or given to parent
#
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

show_usage () {
    printf " Desc: Creates a Windows Event log entry in Application

 usage: logit.sh [-h] [-p] [-i=n] [-s] <description>

 Options:
 -p   Priority (severity):
         0|true|success == SUCCESS
         1|false|error  == ERROR
         2|warn         == WARNING
         3|info         == INFORMATION
 -i   Windows Event ID (create a real one, or use any number)
 -s   The source program associated with the entry
 -h   This cruft

 example: logit.sh -p error -i 501 -s myscript.sh \"failed to run the mount command\"
"
}
get_options () {
    local opts="p:i:s:h"
    while getopts "$opts" OPTIONS; do
        case "$OPTIONS" in
            p)  LGT_PRIORITY="$(get_priority_level "$OPTARG")" ;;
            i)  LGT_ID="$OPTARG"     ;;
            s)  LGT_SOURCE="$OPTARG" ;;
            h)  show_usage; exit 0   ;;
            *)  exit 1 ;;
        esac
    done
}
get_priority_level () {
    local arg="$1"
    case "$arg" in
        0|true|success) printf "SUCCESS" ;;
        1|false|error)  printf "ERROR"   ;;
        2|warn)  printf "WARNING"        ;;
        3|info)  printf "INFORMATION"    ;;
        *)  return 1 ;;
    esac
}
get_desc () {
    [ -z "$1" ] && return 1
    LGT_DESC="$1"
    return 0
}
create_event () {
    local cmd="eventcreate /ID $LGT_ID /L Application /SO $LGT_SOURCE /T $LGT_PRIORITY /D "
    if [[ "$1" == *';'* ]]; then
        local IFS=';'
        for i in "$1"; do
            $cmd "$i" &>/dev/null
        done
    else
        $cmd "$LGT_DESC" &>/dev/null
    fi
}

get_options "$@" && shift $((OPTIND-1))

get_desc "$@" || { echo "Error no description given"; exit 1; }

LGT_TEMP_FILE="$(mktemp --suffix .cmd)"

cat<<EOF>$LGT_TEMP_FILE
@echo off
set LGT_EXITCODE="$LGT_ID"
exit /b %LGT_ID%
EOF

# todo check hash for unix2dos else use sed
unix2dos "$LGT_TEMP_FILE" &>/dev/null

cmd /c "$(cygpath -wa "$LGT_TEMP_FILE")"

create_event

# todo also send to logger and stdout here

rm -f "$LGT_TEMP_FILE"

exit 0
