# #
# Copyright IBM Corp. 2024 - 2024
# SPDX-License-Identifier: Apache-2.0
#

# awk script to convert output from SQL commands to a format
# understood by "sc", a terminal-based spreadsheet calculator.
#   
# num2char(n) -- return a character for a number
#                A=1,...,Z=26,AA=27,...
function num2char(n)
{
  if( n < 27 ){
    return sprintf("%c",64+n)
  } else if( n < 703 ) {
    return sprintf("%c%c",65+(((n-1)/26)-1),65+((n-1)%26))
  } else {
    return sprintf("%c%c%c",65+((((n)/26)-1)/26),65+((((n-1)/26)-1)%26),65+((n-1)%26))
  }
}
function min(a,b)
{
  if( a < b ){ return a }
  return b
}
function max(a,b)
{
  if( a > b ){ return a }
  return b
}
function trace(level,info)
{
  if( trc_level < level ){ return }
  printf "# trace[%d] %s",level,info
  return
}
BEGIN{
       # width of columns given as <first col>:<remaining cols>
           # if width=<num> then this is the width for all columns
           # this setting is just the max width displayed. If the data displayed is smaller
           # then the width will be this smaller value.
           width="30"
       # frame setting
           frame="B1"
           frameColNum=2
           # if freezeColNum is set to 0, then use frame to set the "freeze" area
           freezeColNum=0
       # is there already a frame ? If so, adjust to the new frame size - specify the outer range
           oldRange=""
       # max string length
           # long strings potentially make the processing, and the work within the sheet slow
           # Therefore, the maximum string length limits the length of string data put into the sheet
           maxlen=512
       # max # of columns and rows is given by the limits of the tools displaying the data (sc)
           maxcols=700
           maxrows=32765
       # length of 1st column in case of error output
           errcollen=80
       # string to be used to replace the line break (CR char) in the output
           CRchar="\\n"
       # Either each field is printed out when found, or all data is read, and printed out at the end.
           # In the 2nd case, we can better evaluate the data type for each column - as the data type
           # is the same for all entries of a column.
           # Values:
           #   byValue
           #   bulk
           outMode="bulk"
       # define a gap between columns
           colGap=0
       # define an additional gap between top lines and the SQL headedr info
           headerGap=0
       # choose if an additional "Diagnostics" column should be displayed [1/0] or [y/n]
           diagCol=0
       # define the default path to SC macros
           sc_macro_path="~/.clpsc/Macros"
       # set default colours
           fixedColours="@black;@white|@black;@cyan"
	   notfixedColours="@white;@black|@cyan;@black"

       # array that allows conversion of char to ASCII value
       for(i=0;i<256;i++){ ord[sprintf("%c",i)]=i }

       # internal variables
       nCols=0;nRows=0
       len=0;j=0
       linetype="none"
       headerRow=0
       reclen=0
       msgSize=0
       trc_level=0
     }
{
  trace(1,sprintf("# linetype = \"%s\"\n",linetype))
  trace(1,sprintf("# line = \"%s\"\n",$0))

  # diagnostics
  if( tolower(diagCol) == "y")       { diagCol=1 }
  if( tolower(diagCol) == "n")       { diagCol=0 }
  if( diagCol != 0 && diagCol != 1 ) { diagCol=0 }

  # sc can handle only a limited amount of rows
  if( nRows + headerRow > maxrows ){
    printf "# maxrows = %d reached - need to skip record %d\n",maxrows,NR
    next
  }

  # header line (dashes indicate field lengths)
  if(index($0,"---") == 1){
    if( linetype == "noSQL" ){
      linetype = "header"
    }
    if( linetype == "header" ){
      headerRow--         # the last row in the header contains the column headers => disregard in the noSQL output

      # if we get here, then the previous line (stored in "z[headerRow+1]") contains the column numbers
      # the current line consists of dashes (corresponding to the field widths of CLP output) and
      # single spaces between the dashes. The 2 lines are e.g.
      # MEMBER DB_STATUS        NUM_LOCKS_HELD       ...
      # ------ ---------------- -------------------- ...
      #
      # From this we get the following fields
      #   a[]          column names
      #   e[]          column widths (lengths of the dashed strings)
      #   s[]          offset of the i-th column
      # Later we define
      #   c[][]        cell content (derived from a data line)
      #   t[]          data type of a column
      #   l[]          max data length of the column
      #   r[]          row information
      #   z[]          non-SQL lines ... e.g. lines before the header, or error output

      # the length of the current line should be the length of all output from Db2 CLP
      reclen = length($0)
      nCols=min(NF,maxcols);                     # number of columns of the SQL output
      # get the field lengths
      for(i=1;i<=nCols;i++){
        s[i] = len+1
        e[i] = length($i)
        len = len+1+length($i)
        trace(1,sprintf("# Db2 CLP length of field %d = %d\n",i,e[i]))
      }
      if( diagCol == 1 ){
        e[nCols+1] = 3
        e[nCols+2] = 40
      }
      linetype="dashes"

      # frame
      if( freezeColNum == 0 ){
        # first the row and the column defining the frame
        frameCol=toupper(frame)
        gsub(/[[:digit:]]/,"",frameCol)
        for(i=1;i<=NF;i++){
          if( frameCol == num2char(i) ){
            frameColNum=i
            break
          }
        }
        frameRow=frame
        gsub(/[[:alpha:]]/,"",frameRow)
        frameRow=frameRow+headerRow
      } else {
        frameColNum=freezeColNum+1
        frameRow=headerRow+1
      }
      #frame=sprintf("%c%d",64+frameColNum,frameRow)
      # now, we can get the column names from the saved header line
      # remember that the header line is in z[headerRow+1]
      for(i=1;i<=NF;i++){
        a[i]=substr(z[headerRow+1],s[i],e[i])
        if( match(a[i],/^- *$/) ){
          t[i] = "s"                      # string NULL value
        } else if( match(a[i],/^ *-$/) ){
          t[i] = "i"                      # integer NULL value
        }
        sub(/^ */,"",a[i])  # truncate leading blanks
        sub(/ *$/,"",a[i])  # truncate trailing blanks
        l[i] = length(a[i]) + colGap
      }
      i=split(width,w,/[:,;]/)
      if( i == 1 ){ w[2] = w[1] }
      printf "format A %d 0 0\n",min(e[1],w[1])
      # next line is expected to contain SQL output
      linetype="data"
      next
    }
  }
  # end of header line processing

  # is header found ? if not, save the first line
  # linetype is "none" only in the first line
  if( NF > 0 ){
    if( linetype == "none" ){                                                                    # no linetype set yet
      headerRow++
      z[headerRow] = $0
      linetype = "header"
      #headerRow = headerRow + headerGap
      #maxrows = maxrows - 1 - headerGap
      maxrows = maxrows - 1
    } else if( linetype == "header" ){                                                           # still in the header part ... suspect noSQL
      # if we reach this point, then we have no SQL output from Db2 CLP
      linetype = "noSQL"
      headerRow++
      z[headerRow] = $0
      maxrows = maxrows - 1
    } else if( linetype == "noSQL" ){                                                            # no SQL data found (yet ?)
      headerRow++
      z[headerRow] = $0
    } else if( linetype == "SQLmsg" ){                                                           # processing SQL message text
      msgSize = msgSize + 1
      msg[msgSize] = $0
      gsub(/"/,"\\\"",msg[msgSize])
      maxrows = maxrows - 1
      # we expect the output to end after the message
      next
    } else if( linetype == "check_finished" ){                                                   # data processed, check if data part is finished
      if( NF == 3 && $2 == "record(s)" && $3 == "selected." ) linetype = "finished"
      else                                                    linetype = "data"
    } else if( linetype == "data" ){                                                             # data found
      record = $0
      # concatenate cell content containing line break
      # take care for "output truncated" messages
      if( $1 == "DB29320W" ){
        r[j] = $0
        printf "# r[%d] = \"%s\"\n",j,r[j]
        next
      # now, check for SQL error messages
      } else if( match($1,/^SQL[[:digit:]]{4,5}[NCW]/) == 1 ) {
        linetype = "SQLmsg"
        msg[1] = $0
        msgSize = 1
        gsub(/"/,"\\\"",msg[msgSize])
        maxrows = maxrows - 1
        next
      } else {
        # read input lines until normal record length is reached
        while( length(record) < reclen ){
          getline tmp_record
          record = sprintf( "%s\n%s",record,tmp_record )
        }
      }
      j++;
      nRows++;

      # process the data line following the structure defined by fields e[], s[]
      for(i=1;i<=nCols+2;i++){
        # get a single value
        fld=substr(record,s[i],e[i])
        sub(/^ */,"",fld)      # truncate leading blanks
        sub(/ *$/,"",fld)      # truncate trailing blanks
        gsub(/\n/,CRchar,fld)  # replace CR by "\n" (or what CRchar is set to)

        # determine the data type of cell content ; distinguish between numbers and strings ...
        if( match(fld,/^[-+]?[[:digit:]]{1,}$/) == 1 ){
          t[i] = "i"                              # integer
        } else if( match(fld,/^[-+]?[[:digit:]]{1,}\.[[:digit:]]{1,}$/) == 1 ){
          # length of the exponent part (without sign) - note that sc displays max 6 digits
          curFmt = sprintf( "d%2.2d",min(6,length(substr(fld,index(fld,".")+1,length(fld)))) )
          if( curFmt > t[i] ) t[i] = curFmt       # decimal
        } else if( match(fld,/^[-+][[:digit:]]\.[[:digit:]]{1,}E[+-][[:digit:]]{3}$/) == 1 ){
          # length of the exponent part (without sign)
          curFmt = sprintf( "f%2.2d",length(substr(fld,index(fld,"E")+2,length(fld))) )
          if( curFmt > t[i] ) t[i] = curFmt       # floating point
        } else {
	  if( fld == "-" ) {
            # a simple "-" is not necessarily an indication of a string, but maybe a NULL value
            # therefore, the "-" should not cause a decision for a data type
          }
	  else if( "s" >= t[i] ) {
            t[i] = "s"             # string
            gsub(/"/,"\\\"",fld)
          }
        }
        #print "# data type = ",t[i]

        # check field length
        l[i] = max(l[i],length(fld)+colGap)

        # output now, or later ?
	# bulk output is the default, and is (better) tested
        if( outMode == "byValue" ){
          # print the field now
          switch(t[i]){
            case "i":              printf "let %s%d = %d\n",num2char(i),headerRow+j,fld ; break
            case /d[0-9][0-9]/:    printf "let %s%d = %f\n",num2char(i),headerRow+j,fld ; break
            case /f[0-9][0-9]/:    printf "let %s%d = %E\n",num2char(i),headerRow+j,fld ; break
            case "s":              printf "leftstring %s%d = \"%s\"\n",num2char(i),headerRow+j,substr(fld,1,maxlen) ; break
          }
        } else if( outMode == "bulk" ){
          # store now, and print out at a later time
          c[j][i] = fld
        }
      }
    }
  } else if( linetype == "data" ){
    # we are here since NF = 0
    #   => empty line while processing SQL data
    #   => in the next line we check if we are at the end of the data portion
    linetype = "check_finished"
  }
}

END{
     # colours
     i=split(fixedColours,fColours,/\|/)
     j=split(notfixedColours,nfColours,/\|/)
     if( i != 2 || j != 2 ){
       nfColours[1] = "@white;@black"
       nfColours[2] = "@cyan;@black"
       fColours[1] = "@black;@white"
       fColours[2] = "@black;@cyan"
     }
     print "set color"
     printf "color 1 = %s\n",nfColours[1]
     print "color 2 = @white;@blue"
     printf "color 3 = %s\n",nfColours[2]
     print "color 4 = @yellow;@blue"
     printf "color 5 = %s\n",fColours[1]
     printf "color 6 = %s\n",fColours[2]
     print "color 7 = @red;@cyan"
     print "color 8 = @red;@green"

     # define FKEY settings to run macros
     printf "fkey  5 = \"merge \\\"|%s/%s\\\"\"\n",sc_macro_path,"runSQL.ksh"
     printf "fkey  6 = \"merge \\\"|%s/%s\\\"\"\n",sc_macro_path,"changeParams.ksh"
     printf "fkey  9 = \"merge \\\"|%s/%s\\\"\"\n",sc_macro_path,"fixedCol.ksh"
     printf "fkey 10 = \"merge \\\"|%s/%s\\\"\"\n",sc_macro_path,"setColours.ksh"

     if( oldRange != "" ){
       # if we are here, then there is a previously defined spreadsheet
       # clear old data
       printf "erase %s\n",oldRange
       # remove the frame
       printf "unframe %s\n",oldRange
     }

     # scientific (floating point) formats
     printf "format 5 = \"0.&E+000\"\n"
     printf "format 6 = \"0.&E+0000\"\n"
     printf "format 7 = \"0.&E+00000\"\n"

     if( linetype == "header" || linetype == "noSQL" ){
       # if we reach this point, then we have no SQL output from Db2 CLP
       printf "format A %d 0 0\n",errcollen
       for(i=1;i<=headerRow;i++){
         gsub(/"/,"\\\"",z[i])
         printf "leftstring A%d = \"%s\"\n",i,substr(z[i],1,maxlen)
       }
     } else if(                                          \
                linetype == "finished"        ||         \
                linetype == "check_finished"  ||         \
                linetype == "SQLmsg"          ||         \
                linetype == "data"                       \
              ){                                                          # has processed SQLdata and is finished
       # print the header
       for(i=0;i<headerRow;i++){
         gsub(/"/,"\\\"",z[i+1])
         printf "leftstring A%d = \"%s\"\n",i,substr(z[i+1],1,maxlen)
       }

       # leave free space above the table (headerGap rows) ?
       if( headerRow >= 1 ){
         headerRow = headerRow + headerGap
         maxrows = maxrows - headerGap
         frameRow = frameRow + headerGap
         frame=sprintf("%c%d",64+frameColNum,frameRow)
       }

       # frame command
       # evaluate the col + row for the lower right field
       LRRow = min(nRows+headerRow,maxrows)+msgsize
       if( oldRange != "" ){
         # if we are here, then there is a previously defined spreadsheet (cleared meanwhile)
         # need to adjust structures

         # find corners of old range
         split(oldRange,oldCorners,/:/)
         oldULCol=oldCorners[1]
         gsub(/[[:digit:]]/,"",oldULCol)
         oldULRow=oldCorners[1]
         gsub(/[[:alpha:]]/,"",oldULRow)
         oldLRCol=oldCorners[2]
         gsub(/[[:digit:]]/,"",oldLRCol)
         oldLRRow=oldCorners[2]
         gsub(/[[:alpha:]]/,"",oldLRRow)
         # force conversion to integer
         oldLRRow = oldLRRow + 0
         for(i=1;i<=length(oldLRCol);i++){
           oldLRColNum = oldLRColNum*26+(ord[substr(oldLRCol,i,1)]-64)
         }
         oldLRColNum = oldLRColNum + 0

         # adjust dimensions of the frame
         printf "goto %s%d\n",oldULCol,min(LRRow,oldLRRow)
         if( oldLRRow > LRRow ){
           printf "deleterow * %d\n",oldLRRow-LRRow
         } else {
           printf "insertrow * %d\n",LRRow-oldLRRow
         }
         if( oldLRColNum > nCols ){
           printf "goto %s%d\n",num2char(nCols),0
           printf "deletecol * %d\n",oldLRColNum-nCols
         } else {
           printf "goto %s%d\n",oldLRCol,0
           printf "insertcol * %d\n",nCols-oldLRColNum
         }
       }
       printf "frame A0:%s%d %s:%s%d\n",num2char(nCols+(2*diagCol)),LRRow,frame,num2char(nCols+(2*diagCol)),LRRow
       printf "goto A%d\n",frameRow

       for(i=1;i<=nCols;i++){
         printf "leftstring %s%d = \"%s\"\n",num2char(i),headerRow,substr(a[i],1,maxlen)
       }

       # colors and format of columns
       #   color of header row
       for(i=1;i<=nCols;i++){
         if( i % 2 == 1 ){
           printf "color %s%d:%s%d 6\n",num2char(i),headerRow,num2char(i),headerRow
         } else {
           printf "color %s%d:%s%d 5\n",num2char(i),headerRow,num2char(i),headerRow
         }
       }
       if( nRows > 0 ){
         # set the format for each column
         for(i=1;i<=nCols;i++){
           switch(t[i]){
             case "i":
             case "s":             printf "format %s %d 0 0\n",num2char(i),min(min(e[i],w[2])+colGap,l[i]); break
             case /d[0-9][0-9]/:   printf "format %s %d %d 0\n",num2char(i),min(e[i],w[2])+colGap,substr(t[i],2,2); break
             case /f[0-9][0-9]/:   switch(substr(t[i],2,2)){
                                     case "02": printf "format %s %d %d 1\n",num2char(i),min(e[i],w[2])+colGap,l[i]-6; break
                                     case "03": printf "format %s %d %d 5\n",num2char(i),min(e[i],w[2])+colGap,l[i]-7; break
                                     case "04": printf "format %s %d %d 6\n",num2char(i),min(e[i],w[2])+colGap,l[i]-8; break
                                     case "05": printf "format %s %d %d 7\n",num2char(i),min(e[i],w[2])+colGap,l[i]-9; break
                                     default: printf "# found format %s\n",substr(t[i],2,2);break
                                   }
                                   break
           }
           # set alternating colours so the cell boundaries are recognisable
           #   colours for fixed part of the frame
           if(i<frameColNum){
             if( i % 2 == 1 ){
               printf "color %s%d:%s%d 5\n",num2char(i),headerRow+1,num2char(i),min(nRows+headerRow,maxrows)
             } else {
               printf "color %s%d:%s%d 6\n",num2char(i),headerRow+1,num2char(i),min(nRows+headerRow,maxrows)
             }
           }
           #  colours for the part that is not fixed
           if(i>=frameColNum){
             if( i % 2 == 1 ){
               printf "color %s%d:%s%d 1\n",num2char(i),frameRow,num2char(i),min(nRows+headerRow,maxrows)
             } else {
               printf "color %s%d:%s%d 3\n",num2char(i),frameRow,num2char(i),min(nRows+headerRow,maxrows)
             }
           }
         }
         # "Diagnostics" column
         if( diagCol == 1 ){
           #   header
           printf "leftstring %s%d = \"%s\"\n",num2char(nCols+2),headerRow,"Diagnostics"
           #   format
           printf "format %s %d 0 0\n",num2char(nCols+1),e[nCols+1]
           printf "format %s %d 0 0\n",num2char(nCols+2),e[nCols+2]
           #   header colour
           if( (nCols + 2) % 2 == 1 ){
             printf "color %s%d:%s%d 5\n",num2char(nCols+2),headerRow,num2char(nCols+2),headerRow
           } else {
             printf "color %s%d:%s%d 6\n",num2char(nCols+2),headerRow,num2char(nCols+2),headerRow
           }
           for(i=1;i<=nRows;i++){
             if(substr(r[i],1,index(r[i]," ")-1) == "DB29320W") {
               printf "leftstring %s%d = \"%s\"\n",num2char(nCols+2),headerRow+i,r[headerRow+i]
             }
           }
         } # "Diagnostics" ...
         # in bulk mode the data is blown out not before this point
         # advantage is that we now have a single format per column
         if(outMode == "bulk"){
           for(i=1;i<=nRows;i++){
             for(j=1;j<=nCols;j++){
               # check the data type per column - use the proper command for this data type
               if( c[i][j] == "-" ){
                 switch (t[j]){
                   case "i":
                   case /d[0-9][0-9]/:
                   case /f[0-9][0-9]/:     printf "rightstring %s%d = \"-\"\n",num2char(j),headerRow+i ; break
                   case "s":               printf "leftstring %s%d = \"-\"\n",num2char(j),headerRow+i ; break
                 }
               } else {
                 switch(t[j]){
                   case "i":              printf "let %s%d = %d\n",num2char(j),headerRow+i,c[i][j] ; break
                   case /d[0-9][0-9]/:    printf "let %s%d = %f\n",num2char(j),headerRow+i,c[i][j] ; break
                   case /f[0-9][0-9]/:    printf "let %s%d = %E\n",num2char(j),headerRow+i,c[i][j] ; break
                   case "s":              printf "leftstring %s%d = \"%s\"\n",num2char(j),headerRow+i,substr(c[i][j],1,maxlen) ; break
                 }
               }
             } # columns
           } # rows
         } # bulk
       } # nRows > 0
       # check if SQL messages exist
       if( msgSize > 0 ){
         for(i=1;i<=msgSize;i++){
           printf "leftstring A%d = \"%s\"\n",headerRow+nRows+i,substr(msg[i],1,maxlen)
         }
       } # SQL messages
     } # header | noSQL vs SQL output
   } # END section

