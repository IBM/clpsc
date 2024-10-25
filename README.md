# clpsc
clpsc.ksh: Convert Db2 CLP output to use spreadsheet calculator "sc" for viewing

To make use of clpsc.ksh, you need to have installed sc (https://github.com/n-t-roff/sc). sc has been created in the late 1970s and is a terminal-based, richly featured spreadsheet calculator. Apart from a very detailed manual page, there also is further information available in the WEB pages. You might refer e.g. to the relevant info in wikipedia.

Once installed, you can use clpsc.ksh to display SQL output in a very convenient form. The header of the output containing the columns names is fixed, i.e. is not scrolled with the data. Similarly, by default the first 2 columns are fixed as well.


To move and work in the spreadsheet displaying the result set of a SQL query use simple sc commands. 
  - Use cursor keys and page up/down to move in the spreadsheet. The vi-style commands h,j,k,l work also, as well as H,J,K,L for scrolling in half-page steps.
  - Use 0,^,$,# to move to the begin/top/end/bottom of the spreadsheet.
  - Use i and then r/c to insert a row/column, e.g. to insert further information, or do a calculation ofn data in the spreadsheet.
