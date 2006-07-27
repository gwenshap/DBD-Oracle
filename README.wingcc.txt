14-Sep-2002 -- Michael Chase

Makefile.PL should now create liboci.a for you.  If it fails, follow the
directions below.

19-may-1999

added support for mingw32 and cygwin32 environments.

Makefile.PL should find and make use of OCI include
files, but you have to build an import library for
OCI.DLL and put it somewhere in library search path.
one of the possible ways to do this is issuing command

dlltool --input-def oci.def --output-lib liboci.a

in the directory where you unpacked DBD::Oracle distribution
archive.  this will create import library for Oracle 8.0.4.

Note: make clean removes *.a files, so put a copy in a safe place.
 
