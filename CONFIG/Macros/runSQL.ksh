#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#


#_scmacro_trc=1
. $(dirname $0)/macro_default.ksh

# tracing
if [[ _scmacro_trc -gt 0 ]]; then
  rm -f "${_scmacro_trc_path}"
  touch "${_scmacro_trc_path}"
  _scmacro_teeFile="${_scmacro_trc_path}"
else
  _scmacro_teeFile="/dev/null"
fi

# converter options
set -A _clpsc_convA -- "${_clpsc_convA[@]}" `print -- "${_clpsc_convopts}" | awk -F: '{for(i=1;i<=NF;i++) print $i}' -`

# current position in the spreadsheet
sendCmd "whereami"
_loc="$(readResponse)"
_curloc="$(echo ${_loc} | awk '{print $1}' -)"
_curlocCol="$(sepCol ${_curloc})"
_curlocRow="$(sepRow ${_curloc})"
traceMacro "current: ${_curloc}, Col: ${_curlocCol}, Row: ${_curlocRow}"

sendCmd "getframe"
_frame="$(readResponse)"
set -A _rangeA -- ${_frame}
traceMacro "frame: ${_frame}"

sendCmd "query \"Specify an SQL statement: \""

_SQLtext="$(readResponse 300)"

# if the SQL text starts with a dash, then assume CLP cmdline options + scriptfile
if [[ "${_SQLtext}" = "-"* ]]; then
  set -A _SQLtextA -- ${_SQLtext}
elif [[ -z ${_SQLtext} || $(echo "${_SQLtext}" | awk '{print NF}' -) = "0" ]]; then
  sendMsg "Empty SQL statement"
  sleep 3
  exit
else
  set -A _SQLtextA -- "${_SQLtext}"
fi

sendMsg "Connecting to the DB ${_clpsc_dbname}"
_db2Msg="$(db2Connect)"
traceMacro "${_db2Msg}"

sendMsg "Running the SQL and processing the output ..."
# the awk output contains comments (=> #) ... 
# they appear to not disturb the communication with sc
db2 -v "${_SQLtextA[@]}" | awk -f "${_clpsc_toolpath}/${_clpsc_tab2sc}" "${_clpsc_convA[@]}" oldRange="${_rangeA[0]}" - | tee -a "${_scmacro_teeFile}"
traceMacro "cmd: db2 -v ${_SQLtextA[@]} | awk -f \"${_clpsc_toolpath}/${_clpsc_tab2sc}\" \"${_clpsc_convA[@]}\" oldRange=\"${_rangeA[1]}\" -"
sendMsg "...finished."
_db2Msg="$(db2Terminate)"
traceMacro "${_db2Msg}"

showParams
