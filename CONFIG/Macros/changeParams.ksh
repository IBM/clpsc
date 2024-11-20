#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#

# read in default variables and functions
. $(dirname $0)/macro_default.ksh

# tracing
if [[ _scmacro_trc -gt 0 ]]; then
  rm -f "${_scmacro_trc_path}"
  touch "${_scmacro_trc_path}"
fi

AssignOptValue ()
{
  typeset _qA_rc
  typeset -l _option_=${1%%=*}
  typeset _option_value=\""${1#*=}"\"

  (( _qA_rc = 0 ))
  (( _qA_changed = 0 ))

  if [[ ${_option_} != "help" ]]; then
    if [[ -z $_option_value ]]; then
      print -- "${0##/*/} ERROR: parameter '${_option_}' has no value"
      exit 1
    fi
  fi

  eval _qA_${_option_}=$_option_value 2>/dev/null

  case "${_option_}" in
    dbname)   if [[ "${_clpsc_dbname}" != "${_qA_dbname}" ]]; then
                _clpsc_dbname=$(echo ${_qA_dbname} | tr 'a-z' 'A-Z')
                (( _qA_changed = 1 ))
              fi
              ;;
    schema)   if [[ "${_clpsc_schema}" != "${_qA_schema}" ]]; then
	        _clpsc_schema=$(echo ${_qA_schema} | tr 'a-z' 'A-Z')
                (( _qA_changed = 1 ))
              fi
              ;;
    trace)    if [[ _scmacro_trc -ne ${_qA_trace} ]]; then
                (( _scmacro_trc = ${_qA_trace} ))
                (( _qA_changed = 1 ))
              fi
              #echo "export _scmacro_trc=${_scmacro_trc}" >> "${_clpsc_configdir}/tmp/${_scmacro_name_base}.tmp"
              ;;
    show)     showParams
              #(( _scmacro_loop = 1 ))
              ;;
    done)     (( _scmacro_loop = 1 ))
              ;;
    *)        (( _qA_rc = 1 )) ;;
  esac

  # any settings changed ? if so, write a tmp settings file
  if [[ _qA_changed -eq 1 ]]; then
    {
      echo "_clpsc_dbname=\"${_clpsc_dbname}\""
      echo "_clpsc_schema=\"${_clpsc_schema}\""
      echo "(( _scmacro_trc = ${_scmacro_trc} ))"
    } > ${_scmacro_tmpsettings}
  fi

  return ${_qA_rc}
}

(( _scmacro_loop = 0 ))
while [[ _scmacro_loop -eq 0 ]]; do
  # query action to be performed
  #sendCmd "query \"Type command [dbname|schema|trace|show|done]: \""
  sendCmd "query \"Type command [dbname|schema|trace|done]: \""
  _action="$(readResponse 300)"

  AssignOptValue "${_action}"
  showParams
done

showParams
