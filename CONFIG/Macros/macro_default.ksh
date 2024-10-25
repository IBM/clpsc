#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#

_scmacro_name="${0##*/}"

_clpsc_configdir="${_clpsc_configdir-$HOME/.clpsc}"

_scmacro_name_base="${_scmacro_name}"
_scmacro_name_base="$(basename ${_scmacro_name_base} .ksh)"
_scmacro_name_base="$(basename ${_scmacro_name_base} .bash)"
_scmacro_name_base="$(basename ${_scmacro_name_base} .sh)"

# default timeout (e.g. for reading from sc)
_scmacro_timeout=${_scmacro_timeout-3}
(( _scmacro_timeout = ${_scmacro_timeout} ))

# default trace level/dir/path
_scmacro_trc=${_scmacro_trc-0}
(( _scmacro_trc = ${_scmacro_trc} ))
_scmacro_trc_dir="${_scmacro_trc_dir-${_clpsc_configdir}/Logs}"
_scmacro_trc_path="${_scmacro_trc_dir}/${_scmacro_name_base}.trc"

# after having set the defaults, read in the config
. "${_clpsc_configdir}/clpscrc"

traceMacro()
{
  if [[ _scmacro_trc -gt 0 ]]; then
    echo -e "[${_scmacro_name}][$(date +%Y%m%d%H%M%S)] $@" >> "${_scmacro_trc_path}"
  fi
}

function sepColRow
{
  echo "$1" | awk '{n=match($1,/[[:digit:]]/);print substr($1,1,n-1),substr($1,n,length($1)-n+1)}' -
}

function sepCol
{
  echo $(sepColRow $1 | cut -d' ' -f1)
}

function sepRow
{
  echo $(sepColRow $1 | cut -d' ' -f2)
}

sendCmd()
{
  echo "$@"
  traceMacro "Sending:    '$@'"
}

readResponse()
{
  if [[ $# -gt 0 ]]; then
    (( _scmacro_timeout_tmp = _scmacro_timeout ))
    (( _scmacro_timeout = $1 ))
    shift
  fi
  read -t ${_scmacro_timeout} _response
  if [[ -n _scmacro_timeout_tmp ]]; then
    (( _scmacro_timeout = _scmacro_timeout_tmp ))
  fi
  traceMacro "Response:   '${_response}'"
  echo "${_response}"
}

sendMsg()
{
  echo "error \"$@\""
  traceMacro "Message:    '$@'"
}

col2colno()
{
  _colno=$(echo "$1" | awk 'BEGIN{for(i=0;i<256;i++){ ord[sprintf("%c",i)]=i }}{s=$1;for(i=1;i<=length(s);i++){n=(n*(26^(i-1)))+((ord[substr(s,i,1)]-64))}}END{printf "%d\n",n}' -)
  traceMacro "Col: '$1', Colno = '${_colno}'"
  echo "${_colno}"
}

setAllColours()
{
  sendCmd "getframe"
  _frame="$(readResponse)"
  set -A _rangeA -- ${_frame}
  traceMacro "range: ${_frame}"
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

  # colours
  _colourORowBeg=$(sepRow ${_addrOBeg})
  _colourORowEnd=$(sepRow ${_addrOEnd})
  _colourOColBeg=$(sepCol ${_addrOBeg})
  _colourOColEnd=$(sepCol ${_addrOEnd})
  _colourIRowBeg=$(sepRow ${_addrIBeg})
  _colourIRowEnd=$(sepRow ${_addrIEnd})
  _colourIColBeg=$(sepCol ${_addrIBeg})
  _colourIColEnd=$(sepCol ${_addrIEnd})
  traceMacro "_colourORowBeg: ${_colourORowBeg}"
  traceMacro "_colourORowEnd: ${_colourORowEnd}"
  traceMacro "_colourOColBeg: ${_colourOColBeg}"
  traceMacro "_colourOColEnd: ${_colourOColEnd}"
  traceMacro "_colourIRowBeg: ${_colourIRowBeg}"
  traceMacro "_colourIRowEnd: ${_colourIRowEnd}"
  traceMacro "_colourIColBeg: ${_colourIColBeg}"
  traceMacro "_colourIColEnd: ${_colourIColEnd}"

  # set colours for the set of fixed columns
  (( _i = 0 ))
  sendCmd "seval @coltoa(${_i})"
  _col="$(readResponse)"
  sendCmd "eval @lastcol"
  _lastcol="$(readResponse)"
  (( _nCol = $(col2colno ${_col}) ))
  (( _nColourIColBeg = $(col2colno ${_colourIColBeg}) ))
  while [[ _nCol -lt _nColourIColBeg ]]; do
    # colours 5 + 6
    (( _colourMod = 5 + _i % 2 ))
    sendCmd "color ${_col}${_colourIRowBeg}:${_col}${_colourIRowEnd} ${_colourMod}"
    (( _i = _i + 1 ))
    sendCmd "seval @coltoa(${_i})"
    _col="$(readResponse)"
    (( _nCol = $(col2colno ${_col}) ))
  done

  # set colours for the set of not fixed columns
  while [[ _i -le _lastcol ]]; do
    # colours 1 + 3
    (( _colourMod = 1 + ( _i % 2 ) * 2 ))
    sendCmd "color ${_col}${_colourIRowBeg}:${_col}${_colourIRowEnd} ${_colourMod}"
    (( _i = _i + 1 ))
    sendCmd "seval @coltoa(${_i})"
    _col="$(readResponse)"
  done

  # set colours for the header
  (( _h = _colourIRowBeg - 1 ))
  if [[ _h -ge 0 ]]; then
    (( _i = 0 ))
    sendCmd "seval @coltoa(${_i})"
    _col="$(readResponse)"
    while [[ _i -le _lastcol ]]; do
      # colours 6 + 5
      (( _colourMod = 6 - _i % 2 ))
      sendCmd "color ${_col}${_h}:${_col}${_h} ${_colourMod}"
      (( _i = _i + 1 ))
      sendCmd "seval @coltoa(${_i})"
      _col="$(readResponse)"
    done
  fi
}

function findPPID
{
  _pid=$$
  traceMacro "pid = ${_pid}"
  _psOut0="$(ps -ef | awk '{if($3 == pid){print $0}}' pid=${_pid} | grep -vE 'grep|ps -ef')"
  traceMacro "ps -ef : \n\"${_psOut0}\""
  _ppid="$(echo "${_psOut0}" | awk '{print $3}' -)"
  traceMacro "ppid = ${_ppid}"
  _psOut1="$(ps -ef | grep ${_ppid} | grep -vE 'grep|ps -ef')"
  traceMacro "ps -ef : \n\"${_psOut1}\""

  echo "${_ppid}"

  return 0
}

function db2Connect
{
  db2 -v connect to ${_clpsc_dbname}
  db2 -v set current schema ${_clpsc_schema}

  return $?
}

function db2Terminate
{
  db2 -v terminate

  return $?
}

showParams()
{
  sendMsg "dbinstance=${_clpsc_dbinstance} dbname=${_clpsc_dbname} schema=${_clpsc_schema} trace=${_scmacro_trc}"
}

# use temporary default if available
_ppid=$(findPPID)
_scmacro_tmpsettings="${_clpsc_configdir}/tmp/MacroDefaults_${_ppid}.tmp"
if [[ -f ${_scmacro_tmpsettings} ]]; then
  . ${_scmacro_tmpsettings}
fi

