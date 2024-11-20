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
fi

# current position in the spreadsheet
sendCmd "whereami"
_loc="$(readResponse)"
_curloc="$(echo ${_loc} | awk '{print $1}' -)"
_curUL="$(echo ${_loc} | awk '{print $2}' -)"
_curlocCol="$(sepCol ${_curloc})"
_curlocRow="$(sepRow ${_curloc})"
traceMacro "current: ${_curloc}, Col: ${_curlocCol}, Row: ${_curlocRow}, UL: ${_curUL}"

sendCmd "getframe"
_frame="$(readResponse)"
set -A _rangeA -- ${_frame}
traceMacro "frame: ${_frame}"
set -A _rangeAddr --
for i in "${_rangeA[@]}"; do
  traceMacro "range: ${i}"
  # check if the range is named
  (( n = $(echo $i | awk -F: '{print NF}' -) ))
  if [[ n -eq 1 ]]; then
    # named range => find the addresses
    _named="yes"
    sendCmd "getrange \"${i}\""
    _range="$(readResponse)"
    set -A _rangeAddr -- "${_rangeAddr[@]}" "${_range}"
    traceMacro range of addresses: "${_rangeAddr[@]}"
  else
    # not named => use the info "as is"
    _named="no"
    set -A _rangeAddr -- "${_rangeA[@]}"
  fi
done

_addrOBeg=$(echo ${_rangeAddr[0]} | cut -d: -f1)
_addrOEnd=$(echo ${_rangeAddr[0]} | cut -d: -f2)
_addrIBeg=$(echo ${_rangeAddr[1]} | cut -d: -f1)
_addrIEnd=$(echo ${_rangeAddr[1]} | cut -d: -f2)
traceMacro "_addrOBeg: ${_addrOBeg}"
traceMacro "_addrOEnd: ${_addrOEnd}"
traceMacro "_addrIBeg: ${_addrIBeg}"
traceMacro "_addrIEnd: ${_addrIEnd}"

# freeze columns only if scrolled to the left end
_col=$(sepCol ${_curUL})
_colIBeg=$(sepCol ${_addrIBeg})
(( _nCol = $(col2colno ${_col}) ))
(( _nColIBeg = $(col2colno ${_colIBeg}) ))
if [[ _nCol -gt _nColIBeg && $(sepCol ${_curUL}) != $(sepCol ${_addrIBeg}) ]]; then
  errorMsg "To freeze columns scroll to the left."
  exit -1
fi

_newFrame="frame ${_rangeAddr[0]} $(sepCol ${_curloc})$(sepRow ${_addrIBeg}):${_addrIEnd}"
sendCmd "${_newFrame}"
traceMacro "${_newFrame}"

# colours
setAllColours

showParams
