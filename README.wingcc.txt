29th April 2008 
From Nathan Vonnahme  (nathan.vonnahme at bannerhealth.com)

Hi!  Thanks for maintaining DBD::Oracle!

It might help people like me in the future to include these notes in
README.wingcc.txt or README.win32.txt (hopefully Outlook won't destroy
them)... there might be better ways of doing some of the details too but
it seems to have worked for me:


Compiling DBD::Oracle using the Oracle Instant Client, Cygwin Perl and
gcc

   1. Download these two packages from Oracle's Instant Client for
Windows site
(http://www.oracle.com/technology/software/tech/oci/instantclient/htdocs
/winsoft.html):

      Instant Client Package - Basic: All files required to run OCI,
OCCI, and JDBC-OCI applications
      Instant Client Package - SDK: Additional header files and an
example makefile for developing Oracle applications with Instant Client

      (I usually just use the latest version of the client)

   2. Unpack both into C:\oracle\instantclient_11_1
   3. Download and unpack DBD::Oracle from CPAN to some place with no
spaces in the path (I used /tmp/DBD-Oracle) and cd to it.
   4. Set up some environment variables (it didn;t work until I got the
DSN right):

      ORACLE_DSN=DBI:Oracle:host=oraclehost;sid=oracledb1
      ORACLE_USERID=username/password

   5.

      perl Makefile.PL
      make
      make test
      make install

Note, the TNS Names stuff doesn't always seem to work with the instant
client so Perl scripts need to explicitly use host/sid in the DSN, like
this:

my $dbh = DBI->connect('dbi:Oracle:host=oraclehost;sid=oracledb1',
'username', 'password');





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
 
