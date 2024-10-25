#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#


. $(dirname $0)/macro_default.ksh

#(( _scmacro_trc = 1 ))
# tracing
if [[ _scmacro_trc -gt 0 ]]; then
  rm -f "${_scmacro_trc_path}"
  touch "${_scmacro_trc_path}"
fi

# current position in the spreadsheet
sendCmd "whereami"
_loc="$(readResponse)"
_curloc="$(echo ${_loc} | awk '{print $1}' -)"
_curlocCol="$(sepCol ${_curloc})"
_curlocRow="$(sepRow ${_curloc})"
traceMacro "current: ${_curloc}, Col: ${_curlocCol}, Row: ${_curlocRow}"

setAllColours

showParams
