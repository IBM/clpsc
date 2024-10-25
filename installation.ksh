#!/bin/ksh
#
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#


_configDir="${HOME}/.clpsc"
_binDir="${HOME}/bin"
_instDir="$(dirname $0)"

which sc 1>/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  print -- "Executable 'sc' not found. You need to install it first."
  print -- "You can download 'sc' e.g. from https://github.com/n-t-roff/sc ."
  print -- "Exit"
  exit 1
else
  print -- "Found executable '$(which sc)' => OK"
fi

print -- " "
print -- "Installation directory:     ${_instDir}"
print -- "Configuration directory:    ${_configDir}"
print -- "executable directory:       ${_binDir}"
print -- " "

if [ ! -d "${_configDir}" ]; then
  mkdir "${_configDir}"
fi

if [ ! -d "${_binDir}" ]; then
  mkdir "${_binDir}"
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
