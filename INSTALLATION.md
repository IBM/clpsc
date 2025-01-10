
Do the following:
  - ensure that you have installed sc (e.g. from https://github.com/n-t-roff/sc)
  - ensure that the Korn shell (ksh) is available on the machine
  - download / clone this repository
  - run
      installation.ksh

I recommend to run the installation as user root. Then, the clpsc utility is installed to the OS tree /opt.
First execution of clpsc.ksh will then setup the tool in thei user's $HOME.

If you run the installation as non-root user, then all data is copied directly to $HOME/.clpsc .
