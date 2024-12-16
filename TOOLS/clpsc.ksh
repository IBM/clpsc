#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#


#set -x
_clpsc_prog="${0##*/}"             # name of the script
_clpsc_version_number="0.9.8"
# env var CLPSCDIR indicates an alternative config directory
_clpsc_configdir="${CLPSCDIR-${HOME}/.clpsc}"
export _clpsc_configdir

# if the config directory does not exist, check for a root installation
# and copy / link data from there
if [[ ! -d "${_clpsc_configdir}" ]]; then
  _configDirRoot="/opt/CLPSC/CONFIG"
  if [[ ! -d "${_configDirRoot}" ]]; then
    print -- "[${_clpsc_prog}] ERROR: missing root installation !!"
    exit -1
  fi
  mkdir -p "${_clpsc_configdir}"
  if [[ $? -ne 0 ]]; then
    print -- "[${_clpsc_prog}] ERROR: no configuration directory '${_clpsc_configdir}' !!"
    exit -1
  fi
  ln -s "${_configDirRoot}"/clpscrc "${_clpsc_configdir}"
  ln -s "${_configDirRoot}"/Macros "${_clpsc_configdir}"
  ln -s "${_configDirRoot}"/Tools "${_clpsc_configdir}"
  cp "${_configDirRoot}"/clpscUser.template "${_clpsc_configdir}"
  mkdir "${_clpsc_configdir}"/Logs
  mkdir "${_clpsc_configdir}"/tmp
fi

# default sc path - may be overwritten by the config
_clpsc_scexecpath="$(which sc 2>/dev/null)"

_clpsc_convopts=""
_clpsc_scopts=""
set -A _clpsc_clpoptsA --

_clpsc_if="none"

if [[ -f ${_clpsc_configdir}/clpscrc ]]; then
  . ${_clpsc_configdir}/clpscrc
fi
#if [[ -f ./.clpscrc ]]; then
#  . ./.clpscrc
#fi

if [[ -n ${awkprog} ]]; then
  _clpsc_awkprog="${awkprog}"
  unset awkprog
fi
_clpsc_convTool="${_clpsc_awkprog-/usr/bin/awk}"

# full path of sc executable
if [[ -n ${scexecpath} ]]; then
  _clpsc_scexecpath="${scexecpath}"
  unset scexecpath
fi
# evaluate config file
if [[ -n ${tab2sc} ]]; then
  _clpsc_tab2sc="${tab2sc}"
  unset tab2sc
fi
if [[ -n ${convopts} ]]; then
  _clpsc_convopts="${convopts}"
  unset convopts
fi
if [[ -n ${clpopts} ]]; then
  _clpsc_clpopts="${clpopts}"
  unset clpopts
fi
if [[ -n ${scopts} ]]; then
  _clpsc_scopts="${scopts}"
  unset scopts
fi
if [[ -n ${settings} ]]; then
  _clpsc_settings="${settings}"
  unset settings
  . "${_clpsc_settings}"
fi

#_clpsc_toolpath="/home/mschuene/ArchiveSupport/LOCAL/Tools/SupportScripts"
_clpsc_toolpath="${_clpsc_toolpath:-${_clpsc_configdir}/Tools}"
_clpsc_tab2sc="${_clpsc_tab2sc:-DB2tab2sc.awk}"

# default Db2 instance
_clpsc_dbinstance="${CLPSCDB2INST-${DB2INSTANCE}}"
# default database name
_clpsc_dbname="${CLPSCDBNAME-${DB2DBDFT}}"
# default database schema
_clpsc_schema="${CLPSCSCHEMA-${USER}}"

_clpsc_displayExe="${_clpsc_scexecpath}"

# prevent a setting of CLP option "-x" - this will not display headers so we can't process the output properly
#set -A _clpsc_clpoptsA -- "${_clpsc_clpoptsA[@]}" "+x"
set -A _clpsc_clpoptsA -- "${_clpsc_clpoptsA[@]}" `print -- "${_clpsc_clpopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -` "${_clpsc_clpoptsA[@]}"

# usage
usage ()
{
  echo Usage:
  echo "  ${_clpsc_prog} [option=value [..]] \"SQL statement\""
  echo " "
  echo "  Options:"
  echo "    dbinstance          Db2 instance [\$CLPSCDB2INST | \$DB2INSTANCE]"
  echo "    dbname              database name [\$CLPSCDBNAME | \$DB2DBDFT]"
  echo "    schema              database schema [\$CLPSCSCHEMA | \${USER}]"
  echo "    if                  Input file name (containing output from Db2 CLP)"
  echo "    fcn                 number of columns to freeze [1]"
  echo "    clpopts             options for Db2 CLP (separated by ':')"
  echo "    convopts            options for converter script (separated by ':')"
  echo "    scopts              options for sc (separated by ':')"
  echo "    help                print help info and exit"
  echo "    version             print version info and exit"
}

# command line processing
AssignOptValue ()
{
  typeset _clpsc_rc
  typeset -l _option_=${1%%=*}
  typeset _option_value=\""${1#*=}"\"

  (( _clpsc_rc = 0 ))

  if [[ "${_option_}" != "help" ]]; then
    if [[ -z "${_option_value}" ]]; then
      print -- "${0##/*/} ERROR: parameter '${_option_}' has no value"
      exit 1
    fi
  fi

  eval _clpsc_"${_option_}"="${_option_value}" 2>/dev/null

  case "${_option_}" in
    dbinstance)    ;;
    dbname)        ;;
    help)          usage
                   exit
                   ;;
    fcn)           set -A _clpsc_convA -- "${_clpsc_convA[@]}" "freezeColNum=${_clpsc_fcn}"
                   ;;
    schema)        ;;
    # Note that the CLP options coming from the comand line are being set before the preset options.
    # This is to prevent essential options to be overwritten.
    clpopts)       set -A _clpsc_clpoptsA -- `print -- "${_clpsc_clpopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -` "${_clpsc_clpoptsA[@]}"
                   ;;
    scopts)        set -A _clpsc_scoptsA -- "${_clpsc_scoptsA[@]}" `print -- "${_clpsc_scopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -`
                   set -A _clpsc_displayExeA -- "${_clpsc_scoptsA[@]}"
                   ;;
    convopts)      set -A _clpsc_convA -- "${_clpsc_convA[@]}" `print -- "${_clpsc_convopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -`
                   ;;
    tab2sc)        ;;
    toolpath)      ;;
    options)       set -A _clpsc_optionsA -- "${_clpsc_optionsA[@]}" `print -- "${_clpsc_options}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -`
                   ;;
    scexecpath)    _clpsc_displayExe="${_clpsc_scexecpath}"
                   ;;
    if)            if [[ -z ${_clpsc_if} ]]; then
                     print -- "[ERROR] [${_clpsc_prog}] No input file specified ..."
                     (( _clpsc_rc = 1 ))
                   elif [[ ! -f ${_clpsc_if} ]]; then
                     print -- "[ERROR] [${_clpsc_prog}] Input file does not exist, or is not an ordinary file ..."
                     (( _clpsc_rc = 1 ))
                   fi
                   ;;
    version)       print -- "[${_clpsc_prog}] Version: ${_clpsc_version_number}"
                   print -- "[${_clpsc_prog}] Converter script:\n[${_clpsc_prog}]  " $(echo "dummy" | "${_clpsc_convTool}" -f "${_clpsc_toolpath}/${_clpsc_tab2sc}" showversion=1 -)
                   exit 0
                   ;;
    trace)         _clpsc_displayExe=less
                   set -A _clpsc_displayExeA -- "-S"
                   set -A _clpsc_convA -- "${_clpsc_convA[@]}" "trc_level=${_clpsc_trace}"
                   ;;
    *)             (( _clpsc_rc = 1 ))
                   ;;
  esac

  return ${_clpsc_rc}
}

function db2clp
{
  _clpsc_rc=0

  _clpsc_db2=$(which db2 2>/dev/null)
  (( _clpsc_rc = $? ))

  if [[ _clpsc_rc -eq 0 ]]; then
    ${_clpsc_db2} -v "${@}"
    (( _clpsc_rc = $? ))
  fi

  return ${_clpsc_rc}
}

# set sc options as read in from profiles
set -A _clpsc_scoptsA -- `print -- "${_clpsc_scopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -`
# options for the converter (usually handed to the awk script)
set -A _clpsc_convA -- `print -- "${_clpsc_convopts}" | "${_clpsc_convTool}" -F: '{for(i=1;i<=NF;i++) print $i}' -`
(( _clpsc_grc = 0 ))

# command line parameter processing
while [[ $# -gt 0 ]]; do
  AssignOptValue "$1"
  (( _clpsc_grc = $? ))
  if [[ _clpsc_grc -ne 0 ]]; then
  #  echo "[ERROR] ${_clpsc_prog} rc = ${_clpsc_grc} while processing arguments"
    break
  fi
  shift
done

#if [[ _clpsc_grc -ne 0 ]]; then
  #  echo "[ERROR] ${_clpsc_prog} rc = ${_clpsc_grc} while processing arguments"
#  exit -1
#fi

# prevent a setting of CLP option "-x" - this will not display headers so we can't process the output properly
#set -A _clpsc_clpoptsA -- "${_clpsc_clpoptsA[@]}" "+x"

if [[ -n "${_clpsc_dbinstance}" ]]; then
  _clpsc_dbuser_home=$(getent passwd | grep "${_clpsc_dbinstance}" | cut -d: -f6)
  if [[ -f "${_clpsc_dbuser_home}"/sqllib/db2profile ]]; then
    . "${_clpsc_dbuser_home}"/sqllib/db2profile
  else
    print -- "[${_clpsc_prog}] ERROR: '${_clpsc_dbinstance}' is not a valid Db2 instance"
    exit 1
  fi
fi
if [[ -n "${_clpsc_dbname}" ]]; then
  db2 -v connect to "${_clpsc_dbname}"
fi
if [[ -n "${_clpsc_schema}" ]]; then
  db2 -v set current schema = "${_clpsc_schema}"
fi

typeset -u _clpsc_dbinstance
typeset -u _clpsc_dbname
typeset -u _clpsc_schema

print -- "[${_clpsc_prog}] Parameters:"
print -- "[${_clpsc_prog}]   Db2 instance:\t\t${_clpsc_dbinstance}"
print -- "[${_clpsc_prog}]   Database name:\t\t${_clpsc_dbname}"
print -- "[${_clpsc_prog}]   Database schema:\t\t${_clpsc_schema}"
print -- "[${_clpsc_prog}]   Input file:\t\t${_clpsc_if}"
print -- "[${_clpsc_prog}]   SC exec path:\t\t${_clpsc_scexecpath}"
print -- "[${_clpsc_prog}]   SC options:\t\t${_clpsc_scoptsA[@]}"
print -- "[${_clpsc_prog}]   Tool / script path:\t${_clpsc_toolpath}"
print -- "[${_clpsc_prog}]   Converter options:\t${_clpsc_convA[@]}"
print -- "[${_clpsc_prog}]   tab2sc converter:\t\t${_clpsc_tab2sc}"
print --

# export variables to be used by macros
export _clpsc_dbinstance _clpsc_dbname _clpsc_schema _clpsc_toolpath _clpsc_convopts _clpsc_tab2sc

set -o pipefail
set -o verbose
set -x
# running Db2 CLP, or reading in an input file ?
if [[ "${_clpsc_if}" = "none" ]]; then
  if [[ $# -eq 0 ]]; then
    set +x
    set +o verbose
    print -- "[${_clpsc_prog}] "
    print -- "[${_clpsc_prog}] ERROR: I have no info what to display ... "
    print -- "[${_clpsc_prog}] "
  else
    # run Db2 CLP
    db2 "${_clpsc_clpoptsA[@]}" "${@}" | "${_clpsc_convTool}" -f "${_clpsc_toolpath}/${_clpsc_tab2sc}" "${_clpsc_convA[@]}" - | ${_clpsc_displayExe} "${_clpsc_displayExeA[@]}"
  fi
else
  # read in from an input file
  "${_clpsc_convTool}" -f "${_clpsc_toolpath}/${_clpsc_tab2sc}" "${_clpsc_convA[@]}" "${_clpsc_if}" | ${_clpsc_displayExe} "${_clpsc_displayExeA[@]}"
fi
set +x
set +o verbose

db2clp terminate
