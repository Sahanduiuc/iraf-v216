RPM packages

curl-devel
expat-devel
readline-devel
cfitsio-devel
f2c
tcsh
bison
flex
xmlrpc-c

GOTCHAS

The big gotcha is that IRAF does it's own dynamic memory allocation so
that there is some very strange pointer magic in orde

There is a lot of pointer magic here.  For example there is a patch

    force iraf to align on 128-bit boundaries

    This is necessary for GCC 4.8 to properly generate SSE2 double
        word aligned move instructions.  See

    https://bugs.mageia.org/show_bug.cgi?id=11507

    for discussion of this issue.

----------

Also the c code that is generated by f2c is modified in order to make
the pointers match up.  Unfortunately I fixed it two years ago and
forgot what the problem was, but it had something to do with the size
of doubles generated by f2c

---------------

FORTRAN 95 conversion

Would really like to upgrade IRAF to be able to use fortran95.
However, there is a problem.  IRAF does its only memory allocation and
uses a fortran 77 equivalence statement to locate the base of the
dynamic member and this does not work for fortran 95.