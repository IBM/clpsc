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
_scmacro_timeout=${_scmacro_timeout-1}
(( _scmacro_timeout = ${_scmacro_timeout} ))

# default trace level/dir/path
_scmacro_trc=${_scmacro_trc-0}
(( _scmacro_trc = ${_scmacro_trc} ))
_scmacro_trc_dir="${_scmacro_trc_dir-${_clpsc_configdir}/Logs}"
_scmacro_trc_path="${_scmacro_trc_dir}/${_scmacro_name_base}.trc"
# write a repro script ?
_scmacro_script=${_scmacro_script-0}
(( _scmacro_script = ${_scmacro_script} ))
# path to write a repro script
_scmacro_script_path="${_scmacro_trc_dir}/${_scmacro_name_base}.script"
rm -rf "${_scmacro_script_path}"

# after having set the defaults, read in the config
. "${_clpsc_configdir}/clpscrc"

traceMacro()
{
  typeset _scmacro_trcChk
  typeset _scmacro_trcMsg

  if [[ _scmacro_trc -gt 0 ]]; then
    #(( _scmacro_trcChk = $(echo $1 | awk '{if(length($0) > 1){print "0";next}match($1,/[[:digit:]]/);print RSTART}' -) ))
    (( _scmacro_trcChk = ${#1} ))
    if [[ _scmacro_trcChk -eq 1 ]]; then
      (( _scmacro_trcMsg = $1 ))
      shift
    else
      (( _scmacro_trcMsg = 0 ))
    fi
    if [[ _scmacro_trc -ge _scmacro_trcMsg ]]; then
      echo -e "[${_scmacro_name}][$(date +%Y%m%d%H%M%S.%N)] $@" >> "${_scmacro_trc_path}"
    fi
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
  traceMacro 3 "Sending:    '$@'"
  if [[ _scmacro_script -gt 0 ]]; then
    if [[ "$1" = "seval "*   ||
          "$1" = "eval"*     ||
          "$1" = "get"* ]]; then
      traceMacro 4 "Do not put '$@' into the script"
    else
      echo "$@" >> "${_scmacro_script_path}"
    fi
  fi
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
  traceMacro 3 "Response:   '${_response}'"
  echo "${_response}"
}

sendMsg()
{
  echo "error \"$@\""
  traceMacro "Message:    '$@'"
}

errorMsg()
{
  sendMsg "[E] $@"
}

col2colno()
{
  _colno=$(echo "$1" | awk 'BEGIN{for(i=0;i<256;i++){ ord[sprintf("%c",i)]=i }}{s=$1;for(i=1;i<=length(s);i++){n=(n*(26^(i-1)))+((ord[substr(s,i,1)]-64))}}END{printf "%d\n",n}' -)
  traceMacro "Col: '$1', Colno = '${_colno}'"
  echo "${_colno}"
}

function getSection
{
  if [[ $# -lt 2 ]]; then
    errorMsg "Incorrect number of args in $0"
    return 1
  fi
  awk 'BEGIN{p=0}
       {
         # ignore lines with comment
         if( index($1,"#") == 1){next}
         # get section identifiers
         n = split($0,a,/[\[\]]/,seps)
         if(n == 3 && seps[1] == "[" && seps[2] == "]"){
           sub(/^[[:blank:]]*/,"",a[2])
           sub(/[[:blank:]]*$/,"",a[2])
           # printf "a[2] = %s\n",a[2]
           # if this is the desired section, ensure it is printed
           if( a[2] == sectionName ){p = 1}  # print the section content
           else                     {p = 0}  # ignore the section
         } else if( NF > 0 ){
           if( $1 == "#" ){ next }
           else if( p == 1 ){
             s = $0
             sub(/^[[:blank:]]*/,"",s)
             sub(/[[:blank:]]*$/,"",s)
             print s
           }
         }
       }' sectionName="$1" "$2"

  return 0
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

  typeset _addrOBeg=$(echo ${_rangeAddr[0]} | cut -d: -f1)
  typeset _addrOEnd=$(echo ${_rangeAddr[0]} | cut -d: -f2)
  typeset _addrIBeg=$(echo ${_rangeAddr[1]} | cut -d: -f1)
  typeset _addrIEnd=$(echo ${_rangeAddr[1]} | cut -d: -f2)
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
  _psOut0="$(ps -ef | awk '{if($2 == pid){print $0}}' pid=${_pid} | grep -vE 'grep|ps -ef')"
  traceMacro "ps -ef : \n\"${_psOut0}\""
  _ppid="$(echo "${_psOut0}" | awk '{print $3}' -)"
  traceMacro "ppid = ${_ppid}"
  _psOut1="$(ps -ef | grep ${_ppid} | grep -vE 'grep|ps -ef')"
  traceMacro "ps -ef : \n\"${_psOut1}\""

  echo "${_ppid}"

  return 0
}

function setDb2InstEnv
{
  (( _rc = 0 ))

  if [[ -n "${_clpsc_dbinstance}" ]]; then
    _dbuser_home=$(getent passwd | grep "${_clpsc_dbinstance}" | cut -d: -f6)
    if [[ -f "${_dbuser_home}"/sqllib/db2profile ]]; then
      . "${_dbuser_home}"/sqllib/db2profile
    else
      errorMsg "'${_clpsc_dbinstance}' is not a valid Db2 instance"
      (( _rc = 1 ))
    fi
  fi

  return ${_rc}
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

# use defaults set
_scmacro_settings="${_clpsc_configdir}/MacroDefaults"
if [[ -f ${_scmacro_settings} ]]; then
  . ${_scmacro_settings}
fi
# use temporary default if available
_ppid=$(findPPID)
_scmacro_tmpsettings="${_clpsc_configdir}/tmp/MacroDefaults_${_ppid}.tmp"
if [[ -f ${_scmacro_tmpsettings} ]]; then
  . ${_scmacro_tmpsettings}
fi

