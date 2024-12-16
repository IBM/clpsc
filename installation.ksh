#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#


_configDir="${HOME}/.clpsc"
_binDir="${HOME}/bin"
_instDir="$(dirname $0)"

_configDirRoot="/opt/CLPSC/CONFIG"
_binDirRoot="/usr/local/bin"

#_scPath="/usr/local/bin/sc"
_scPath=""

print -- " "
print -- "Installation procedure for 'clpsc' - a wrapper fo the Db2 CLP."
print -- " "

if [ -z ${_scPath} ]; then
  print -- "No path to 'sc' provided."
  print -- "This is OK - I will try to find 'sc' myself ..."
  print -- " "
  which sc 1>/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    print -- "Executable 'sc' not found. You need to install it first."
    print -- "You can download 'sc' e.g. from https://github.com/n-t-roff/sc ."
    print -- "Exit"
    exit 1
  else
    _scPath="$(which sc)"
  fi
else
  print -- "Found path to 'sc' as '${_scPath}' ... testing ..."
  print -- " "
  if [ ! -e ${_scPath} ]; then
    print -- "File '${_scPath}' is not executable."
    print -- "Exit"
    exit 1
  fi
fi
print -- "Using executable '${_scPath}' ..."

if [[ $(id -u) -eq 0 ]]; then
  print -- "\nInstallation as 'root' ... \n"
  _configDir="${_configDirRoot}"
  _binDir="${_binDirRoot}"
fi

print -- " "
print -- "Installation directory:     ${_instDir}"
print -- "Configuration directory:    ${_configDir}"
print -- "executable directory:       ${_binDir}"
print -- " "
print -- "Using 'sc' from:            ${_scPath}"
print -- " "

if [ ! -d "${_configDir}" ]; then
  mkdir -p "${_configDir}"
fi

if [ ! -d "${_binDir}" ]; then
  mkdir -p "${_binDir}"
fi

print -- "Copy configuration ..."
( cd "${_instDir}" && cp -r CONFIG/* "${_configDir}" )
print -- "... done"
print -- "Copy script ..."
( cd "${_instDir}" && cp -r TOOLS/clpsc.ksh "${_binDir}" )
print -- "... done"

print -- " "
print -- "Set permissions ..."
chmod 755 "${_configDir}/Macros/"*
chmod 755 "${_binDir}/clpsc.ksh"
print -- "... done"
print -- " "

print -- "Finished successfully."
