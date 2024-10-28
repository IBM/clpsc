# `clpsc.ksh`

`clpsc.ksh`: Convert Db2 CLP output to use spreadsheet calculator `sc` for viewing

# How to call `clpsc.ksh`

Command line options of `clpsc.ksh` are specified using option=value. Valid options and their defaults are listed below.

```
    dbinstance          Db2 instance [$CLPSCDB2INST | $DB2INSTANCE]
    dbname              database name [$CLPSCDBNAME | $DB2DBDFT]
    schema              database schema [$CLPSCSCHEMA | ${USER}]
    if                  Input file name (containing output from Db2 CLP)
    fcn                 number of columns to freeze [1]
    clpopts             options for Db2 CLP (separated by ':')
    convopts            options for converter script (separated by ':')
    scopts              options for sc (separated by ':')
    version             print version info and exit
```

Run `clpsc.ksh` using a syntax following one of the examples below:

  - `clpsc.ksh option=value [...] "<SQL command>"`
  - `clpsc.ksh option=value [...] <CLP options> -f <SQL file>`
  - `clpsc.ksh option=value [...] if=<input file>`

Here, the `<SQL file>` is a file containing an SQL command. Depending on how the SQL command is terminated, you need to use CLP options `-t`, or `-td<terminator>`. `<input file>` is a file containing CLP output. If no input file is used, then the Db2 instance, and the database name need to be specified, either via environment, or via command line.

You can use `clpsc.ksh` to display SQL output in a very convenient form. The header of the output containing the columns names is fixed, i.e. is not scrolled with the data. Similarly, by default the first column is fixed as well. The data is displayed in alternating foreground/background colours.

`clpsc.ksh` sends data from the Db2 CLP into a converter script. This is an awk script that can be tuned using command line options. The output of the script is then sent to `sc`.

# Using F keys

When displaying data using `clpsc.ksh`, `sc` is configured to use a set of fixed columns. To change the number of fixed columns press F9. Then all columns before the cursor are fixed, while all columns from the cursor up to the last column are not fixed. However, this will only work, if the result set is not scrolled horizontally (i.e. is in the leftmost position). The colouring is adjusted automatically.

As you can insert and delete columns and rows, the colouring scheme may get mixed up. You can re-adjust the colouring using F10.

# Configuration

The default configuration directory of `clpsc.ksh` is `${HOME}/.clpsc`. You can change that using environment variable `CLPSCDIR`. I you would like to override the configuration in `clpscrc` located in the configuration directory, then do that in `clpscUser`. A template is part of the package.

## Configuration of the awk script

For the awk script use the following options:

```
    maxlen              maximum field length [512]
    headerGap           number of lines between the displayed SQL command and the result set [0]
    colGap              width of the gap between columns [0]
    freezeColNum        number of frozen columns [0]
    fixedColours        colour settings for fixed columns [@black;@white|@black;@cyan]
    notFixedColours     colour settings for columns that are not fixed [@white;@black|@cyan;@black]
```

Displayed defaults are those of the awk script, not of `clpsc.ksh`.

To submit your setting to `clpsc.ksh`, specify them colon-separated using parameter `convopts` in your configuration.

# Pre-requisites

To make use of `clpsc.ksh`, you need to have installed [`sc`](https://github.com/n-t-roff/sc). `sc` has been created in the late 1970s and is a terminal-based, richly featured spreadsheet calculator. Apart from a very detailed manual page, there also is further information available in the WEB pages. You might refer e.g. to the relevant info in wikipedia.

The SQL output, the fixed columns, and the columns that are not fixed are coloured so that these areas can be visually distinguished easily.

# Limitations

The script can handle data limited by following conditions:

  - `sc` can handle a maximum of 32768 rows and 702 columns. All data beyond that range is ignored.
  - The Db2 CLP can display field lengths up to 8k. All field content beyond that limit is truncated. The actual version of `sc` downloaded from github can handle field lengths up to 10k. Older versions of `sc` can handle only 1k. Therefore the `clpsc.ksh` default is 1000. You can configure the awk script using option `maxlen` to adjust the the max length allowed.

# Some words on `sc`

To move and work in the spreadsheet displaying the result set of a SQL query use simple `sc` commands.
  - Use cursor keys and page up/down to move in the spreadsheet. The vi-style commands h,j,k,l work also, as well as H,J,K,L for scrolling in half-page steps.
  - Use 0,^,$,# to move to the begin/top/end/bottom of the spreadsheet.
  - Use i and then r/c to insert a row/column, e.g. to insert further information, or do a calculation ofn data in the spreadsheet.
  - Use Ctrl-L to refresh the screen.
  - Use g to go to some cell - e.g. "g ae5". You also can use the sc command g to search for a string, if you enclose the search string into double quotes (").

