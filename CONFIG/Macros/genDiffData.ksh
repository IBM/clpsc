#!/bin/ksh

#_scmacro_trc=1
. $(dirname $0)/macro_default.ksh

_sc_thisMacro_config="${_clpsc_configdir}/genDiffData.config"
if [[ ! -f ${_sc_thisMacro_config} ]]; then
  errorMsg "${0}: config '${_sc_thisMacro_config}' does not exist"
  exit -1
fi

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

function isNumCol
{
  typeset _col
  typeset _colRange
  typeset _response
  typeset _i

  if [[ $# -eq 0 ]]; then
    return -1
  fi

  _colRange="$1"
  set -A _colRangeA -- $(echo ${_colRange} | tr ':' ' ')
  if [[ ${#_colRangeA[@]} -ne 2 ]]; then
    return -1
  fi
  _colRangeCB=$(sepCol ${_colRangeA[0]})
  _colRangeCE=$(sepCol ${_colRangeA[1]})
  if [[ ${_colRangeCB} != ${_colRangeCE} ]]; then
    return -1
  fi
  (( _colRangeRB = $(sepRow ${_colRangeA[0]}) ))
  (( _colRangeRE = $(sepRow ${_colRangeA[1]}) ))

  (( _i = _colRangeRB ))
  while [[ _i -le _colRangeRE ]]; do
    # check if the cell is a number - if so, then the row is a number row
    sendCmd "getnum ${_colRangeCB}${_i}"
    _response="$(readResponse)"
    if [[ -n ${_response} ]]; then
      return 1
    else
      sendCmd "getstring ${_colRangeCB}${_i}"
      _response="$(readResponse)"
      if [[ -n ${_response} ]]; then
        if [[ ${_response} != "-" ]]; then
          return 0
        fi
      fi
    fi
    (( _i = _i + 1 ))
  done

  # no number
  return 0
}

function isCounterCol
{
  typeset _rc
  typeset _i

  if [[ $# -ne 2 ]]; then
    return -1
  fi
  isNumCol $2
  (( _rc = $? ))
  # if this is not a numeric column, then it's no counter column
  if [[ _rc -eq 0 ]]; then
    return $_rc
  fi

  _checkColName="$1"
  set -A _noDiffColsA -- $(getSection NoDiffValues "${_sc_thisMacro_config}")
  (( _i = 0 ))
  while [[ _i -le ${#_noDiffColsA[@]} ]]; do
    if [[ "${_noDiffColsA[_i]}" = "${_checkColName}" ]]; then
      #return $_rc
      return 0
    fi
    (( _i = _i + 1 ))
  done

  return $_rc
}

function atocol
{
  if [[ $# -ne 1 ]]; then
    errorMsg "Incorrect number of args in $0"
    return 1
  fi

  echo "$1" | awk 'BEGIN{for(i=0;i<256;i++){ ord[sprintf("%c",i)]=i };col=-1}
                   {
                     if( match($0,/[^[:alpha:]]/) == 0 ){
                       for(i=1;i<=length($0);i++){
                         col=((col+1)*26)+ord[toupper(substr($0,i,1))]-65
                       }
                     }
                   }
                   END{printf "%d\n",col}' -

  return 0
}

function nextCol
{
  if [[ $# -ne 1 ]]; then
    return -1
  fi

  typeset _col
  typeset _nextACol=""

  (( _col = $(atocol $1) ))
  (( _col = _col + 1 ))
  sendCmd "seval @coltoa(${_col})"
  _nextACol=$(readResponse)

  echo ${_nextACol}

  return 0
}

#(( _scmacro_trc = 1 ))
#(( _scmacro_trc = 0 ))
# tracing
if [[ _scmacro_trc -gt 0 ]]; then
  rm -f "${_scmacro_trc_path}"
  touch "${_scmacro_trc_path}"
fi

(( _rowGapBetweenData = 5 ))

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

# separate the frame addresses into rows and columns
_addrOBegRow=$(sepRow ${_addrOBeg})
_addrOEndRow=$(sepRow ${_addrOEnd})
_addrOBegCol=$(sepCol ${_addrOBeg})
_addrOEndCol=$(sepCol ${_addrOEnd})
_addrIBegRow=$(sepRow ${_addrIBeg})
_addrIBegCol=$(sepCol ${_addrIBeg})
# header row
(( _headerRow = _addrIBegRow - 1 ))
traceMacro "_headerRow: ${_headerRow}"

# insert the col to calculate the time diff
sendCmd "goto ${_addrOBeg}"
sendCmd "insertcol"
# adjust frame dimension variables
(( _col = $(atocol ${_addrOEndCol}) ))
(( _col = _col + 1 ))
sendCmd "seval @coltoa(${_col})"
_addrOEndCol=$(readResponse)
#_addrOEndCol=$(nextCol ${_addrOEndCol})
(( _col = $(atocol ${_addrIBegCol}) ))
(( _col = _col + 1 ))
sendCmd "seval @coltoa(${_col})"
_addrIBegCol=$(readResponse)
#_addrIBegCol=$(nextCol ${_addrIBegCol})
_addrOEnd="${_addrOEndCol}${_addrOEndRow}"
_addrIBeg="${_addrIBegCol}${_addrIBegRow}"
_rangeAddr[0]=${_addrOBeg}:${_addrOEnd}
_rangeAddr[1]=${_addrIBeg}:${_addrOEnd}
# fill the column that has been added
(( _i = _addrIBegRow ))
(( _col = $(atocol ${_addrOBegCol}) ))
(( _col = _col + 1 ))
sendCmd "seval @coltoa(${_col})"
_colTimeISO=$(readResponse)
#_colTimeISO=$(nextCol ${_addrOBegCol})
while [[ _i -le _addrOEndRow ]]; do
  sendCmd "getstring ${_colTimeISO}${_i}"
  _timeISO="$(readResponse)"
  sendCmd "let ${_addrOBegCol}${_i} = @dts(@ston(@substr(B${_i},1,4)),@ston(@substr(B${_i},6,7)),@ston(@substr(B${_i},9,10)))+@tts(@ston(@substr(B${_i},12,13)),@ston(@substr(B${_i},15,16)),@ston(@substr(B${_i},18,19)))+(@ston(@substr(B${_i},21,26))/1000000)"
  (( _i = _i + 1 ))
done

# number of rows in the frame
(( _frameVOSize = _addrOEndRow - _addrOBegRow + 1 ))
(( _frameVISize = _addrOEndRow - _addrIBegRow + 1 ))

sendMsg "Checking columns ..."
sendCmd "redraw"
_response="$(readResponse)"
# get the group by column list
set -A _groupByColsA -- $(getSection GroupByCols "${_sc_thisMacro_config}")
(( _i = 0 ))
(( _numOEndCol = $(atocol ${_addrOEndCol}) ))
traceMacro "_headerRow: ${_headerRow}, _numOEndCol = ${_numOEndCol}, _addrOEndCol = ${_addrOEndCol}"
_sort_advice=""
while [[ _i -le _numOEndCol ]]; do
  sendCmd "seval @coltoa(${_i})"
  _response="$(readResponse)"
  _this_colID="${_response}"
  sendCmd "getstring ${_this_colID}${_headerRow}"
  _response="$(readResponse)"
  _this_colName="${_response}"
  traceMacro "name of column ${_this_colID}: '${_this_colName}'"
  (( _is_groupByCol = $(print -- "${_groupByColsA[@]}" | awk 'BEGIN{fnd=0}{for(i=1;i<=NF;i++){if($i == cn){fnd=1}}}END{print fnd}' cn="${_this_colName}" -) ))
  if [[ _is_groupByCol -eq 1 ]]; then
    # check if the first entry in this column is a number
    sendCmd "getnum ${_this_colID}${_addrIBegRow}"
    _response="$(readResponse)"
    if [[ -n ${_response} ]]; then
      _sortChar="#"
    else
      _sortChar='$'
    fi
    _sort_advice=$(printf "%s+%s%s" "${_sort_advice}" "${_sortChar}" "${_this_colID}")
    set -A _sortColsA -- "${_sortColsA[@]}" "${_this_colID}:${_sortChar}"
  fi
  (( _i = _i + 1 ))
done
_sort_advice=$(printf "%s+\$A" "${_sort_advice}")
set -A _sortColsA -- "${_sortColsA[@]}" "A:$"
traceMacro "Sort advice: ${_sort_advice}"

# remove the frame from the data
sendCmd "unframe ${_rangeAddr[0]}"

# sort the data
sendMsg "Sorting the frame ..."
sendCmd "redraw"
_response="$(readResponse)"
sendCmd "sort ${_addrOBegCol}${_addrIBegRow}:${_addrOEndCol}${_addrOEndRow} \"${_sort_advice}\""

# place all data in the buffer
sendMsg "Copying the data to the buffer ..."
sendCmd "redraw"
(( _curRow = _addrOBegRow ))
sendCmd "goto A${_curRow}"
sendCmd "yankrow * ${_frameVOSize}"

# copy the data below the current data set
sendMsg "Inserting the data to the sheet ..."
sendCmd "redraw"
(( _curRow = _addrOEndRow + _rowGapBetweenData ))
sendCmd "goto A${_curRow}"
sendCmd "pullcopy"

# re-define the frame for the data
sendMsg "Creating the frames ..."
sendCmd "redraw"
# re-create the old frame
sendCmd "frame ${_rangeAddr[0]} ${_rangeAddr[1]}"
# new frame boundaries (for data that have been copied)
(( _newOBegRow = _addrOBegRow + _frameVOSize + _rowGapBetweenData - 1 ))
(( _newOEndRow = _addrOEndRow + _frameVOSize + _rowGapBetweenData - 1 ))
(( _newIBegRow = _addrIBegRow + _frameVOSize + _rowGapBetweenData - 1 ))
(( _newHeaderRow = _headerRow + _frameVOSize + _rowGapBetweenData - 1 ))
# define the frame for the copied data
sendCmd "frame ${_addrOBegCol}${_newOBegRow}:${_addrOEndCol}${_newOEndRow} ${_addrIBegCol}${_newIBegRow}:${_addrOEndCol}${_newOEndRow}"
#traceMacro "goto cells ${_addrIBegCol}${_newIBegRow} and ${_addrIBegCol}${_addrIBegRow} and set the colours"
sendCmd "leftstring ${_addrOBegCol}${_headerRow} = \"TIMEDIFF\""
sendCmd "leftstring ${_addrOBegCol}${_newHeaderRow} = \"TIME_SEC\""
sendCmd "format ${_addrOBegCol} 18 6 0"
sendCmd "goto ${_addrIBegCol}${_newIBegRow}"
setAllColours
sendCmd "goto ${_addrIBegCol}${_addrIBegRow}"
setAllColours

# calculate diffs ...
sendMsg "Calculating diffs ..."
sendCmd "redraw"
# Use the data that have been copied as data basis for the calculations
# skip the header line
(( _i = 0 ))
(( _k = ${#_sortColsA[@]} - 1 ))
traceMacro "_frameVISize: ${_frameVISize}, #_sortColsA[@]: ${#_sortColsA[@]}"
while [[ _i -lt _frameVISize ]]; do
  (( _curDBR = _newIBegRow + _i ))
  (( _prvDBR = _newIBegRow + _i - 1 ))
  (( _curCDR = _addrIBegRow + _i ))
  (( _prvCDR = _addrIBegRow + _i - 1 ))
  (( _j = 0 ))

  while [[ _j -lt _k ]]; do
    _col=${_sortColsA[$_j]}
    _dataCol="$(echo ${_col} | cut -d: -f1)"
    _dataType="$(echo ${_col} | cut -d: -f2)"
    traceMacro "_i = ${_i}, _j = ${_j}, _k = ${_k}, _col = ${_col}, _dataCol = ${_dataCol}, _dataType = ${_dataType}"
    [[ ${_dataType} = "#" ]] && sendCmd "getnum ${_dataCol}${_curDBR}"
    [[ ${_dataType} = "$" ]] && sendCmd "getstring ${_dataCol}${_curDBR}"
    _response="$(readResponse)"
    _curVal="${_response}"
    [[ ${_dataType} = "#" ]] && sendCmd "getnum ${_dataCol}${_prvDBR}"
    [[ ${_dataType} = "$" ]] && sendCmd "getstring ${_dataCol}${_prvDBR}"
    _response="$(readResponse)"
    _prvVal="${_response}"
    if [[ "${_curVal}" = "${_prvVal}" ]]; then
      traceMacro "${_dataCol}${_curDBR}: ${_curVal} = ${_prvVal}"
    else
      traceMacro "${_dataCol}${_curDBR}: ${_curVal} != ${_prvVal}"
      sendCmd "erase ${_addrIBegCol}${_curCDR}:${_addrOEndCol}${_curCDR}"
      sendCmd "erase ${_addrOBegCol}${_curCDR}"
      (( _j = _k ))
    fi
    (( _j = _j + 1 ))
  done
  (( _i = _i + 1 ))
  if [[ $(expr ${_i} % 100) -eq 0 ]]; then
    sendMsg "Checking grouped rows (${_i})/${_frameVISize}) ..."
    sendCmd "redraw"
  fi
done

sendMsg "Calculating diffs [inserting diff calculations] ..."
sendCmd "redraw"
_col=${_addrOBegCol}
(( _colNo = $(atocol ${_col}) ))
(( _colMaxNo = $(atocol ${_addrOEndCol}) ))
while [[ _colNo -le _colMaxNo ]]; do
  #sendCmd "getstring ${_dataCol}${_prvDBR}"
  sendCmd "getstring ${_col}${_newHeaderRow}"
  _headerName=$(readResponse)
  isCounterCol "${_headerName}" ${_col}${_newIBegRow}:${_col}${_newOEndRow}
  _isCounterCol=$?
  if [[ _isCounterCol -eq 1 ]]; then
    traceMacro "Col ${_col} (${_colNo}) is a counter column"
    sendMsg "Calculating diffs [column ${_col}/${_addrOEndCol}] ..."
    sendCmd "getstring ${_col}${_headerRow}"
    _response="$(readResponse)"
    sendCmd "leftstring ${_col}${_headerRow} = \"*${_response}\""
    sendCmd "redraw"
    (( _i = 0 ))
    while [[ _i -le _frameVISize ]]; do
      (( _curDBR = _newIBegRow + _i ))
      (( _prvDBR = _newIBegRow + _i - 1 ))
      (( _curCDR = _addrIBegRow + _i ))
      (( _prvCDR = _addrIBegRow + _i - 1 ))
      sendCmd "getnum ${_col}${_curCDR}"
      _curVal=$(readResponse)
      if [[ -n "${_curVal}" ]]; then
        if [[ ${_col} = ${_addrOBegCol} ]]; then
          sendCmd "let ${_col}${_curCDR} = ${_col}${_curDBR}-${_col}${_prvDBR}"
        else
          #sendCmd "let ${_col}${_curCDR} = @if((${_addrOBeg}>0),((${_col}${_curDBR}-${_col}${_prvDBR})/${_addrOBegCol}${_curCDR})*${_addrOBeg},(${_col}${_curDBR}-${_col}${_prvDBR}))"
          sendCmd "let ${_col}${_curCDR} = (${_col}${_curDBR}-${_col}${_prvDBR})*@if((${_addrOBeg}>0),${_addrOBeg}/${_addrOBegCol}${_curCDR},1)"
        fi
      fi
      (( _i = _i + 1 ))
    done
  #else
    #sendMsg "Referring to source cells [column ${_col}] ..."
    #sendCmd "redraw"
    #isNumCol "${_headerName}" ${_col}${_newIBegRow}:${_col}${_newOEndRow}
    #(( _isNumCol = $? ))
    #(( _i = 0 ))
    #while [[ _i -le _frameVISize ]]; do
    #  (( _curDBR = _newIBegRow + _i ))
    #  (( _curCDR = _addrIBegRow + _i ))
    #  sendCmd "getnum ${_col}${_curCDR}"
    #  _curVal=$(readResponse)
    #  if [[ -n "${_curVal}" ]]; then
    #    if [[ ${_col} = ${_addrOBegCol} ]]; then
    #      sendCmd "let ${_col}${_curCDR} = ${_col}${_curDBR}-${_col}${_prvDBR}"
    #    else
    #      #sendCmd "let ${_col}${_curCDR} = @if((${_addrOBeg}>0),((${_col}${_curDBR}-${_col}${_prvDBR})/${_addrOBegCol}${_curCDR})*${_addrOBeg},(${_col}${_curDBR}-${_col}${_prvDBR}))"
    #      sendCmd "let ${_col}${_curCDR} = (${_col}${_curDBR}-${_col}${_prvDBR})*@if((${_addrOBeg}>0),${_addrOBeg}/${_addrOBegCol}${_curCDR},1)"
    #    fi
    #  fi
    #  (( _i = _i + 1 ))
    #done
  fi
  (( _colNo = _colNo + 1 ))
  sendCmd "seval @coltoa(${_colNo})"
  _col=$(readResponse)
done

sendMsg "Cleanup ..."
sendCmd "redraw"
# as last step:
# if the previous row was erase as well, then there is just one row for this item
# in that case, we cannot calculate diffs, and the previous row can be deleted
(( _i = 0 ))
(( _row = -1 ))
(( _lastErased = -1 ))
while [[ _i -le _frameVISize ]]; do
  (( _row = _addrIBegRow + _i ))
  (( _prevRow = _row - 1 ))
  sendCmd "getexp ${_addrOBegCol}${_row}"
  _response=$(readResponse)
  if [[ -z "${_response}" ]]; then
    if [[ _lastErased -eq _prevRow ]]; then
      set -A _toBeDeleted -- "${_prevRow}" "${_toBeDeleted[@]}"
    fi
    (( _lastErased = _row ))
  fi
  (( _i = _i + 1 ))
done
for _row in ${_toBeDeleted[@]}; do
  sendCmd "deleterow ${_row}"
done

sendMsg "... done"
sendCmd "redraw"
