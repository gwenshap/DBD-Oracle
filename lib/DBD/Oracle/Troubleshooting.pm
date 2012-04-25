package DBD::Oracle::Troubleshooting;
{
  $DBD::Oracle::Troubleshooting::VERSION = '1.45_00';
}
BEGIN {
  $DBD::Oracle::Troubleshooting::AUTHORITY = 'cpan:PYTHIAN';
}
#ABSTRACT: Tips and Hints to Troubleshoot DBD::Oracle


__END__
=pod

=head1 NAME

DBD::Oracle::Troubleshooting - Tips and Hints to Troubleshoot DBD::Oracle

=head1 VERSION

version 1.45_00

=head1 CONNECTING TO ORACLE

If you are reading this it is assumed that you have successfully
installed DBD::Oracle and you are having some problems connecting to
Oracle.

First off you will have to tell DBD::Oracle where the binaries reside
for the Oracle client it was compiled against.  This is the case when
you encounter a

 DBI connect('','system',...) failed: ERROR OCIEnvNlsCreate.

error in Linux or in Windows when you get

  OCI.DLL not found

The solution to this problem in the case of Linux is to ensure your
'ORACLE_HOME' (or LD_LIBRARY_PATH for InstantClient) environment
variable points to the correct directory.

  export ORACLE_HOME=/app/oracle/product/xx.x.x

For Windows the solution is to add this value to you PATH

  PATH=c:\app\oracle\product\xx.x.x;%PATH%

If you get past this stage and get a

  ORA-12154: TNS:could not resolve the connect identifier specified

error then the most likely cause is DBD::ORACLE cannot find your .ORA
(F<TNSNAMES.ORA>, F<LISTENER.ORA>, F<SQLNET.ORA>) files. This can be
solved by setting the TNS_ADMIN environment variable to the directory
where these files can be found.

If you get to this stage and you have either one of the following
errors;

  ORA-12560: TNS:protocol adapter error
  ORA-12162: TNS:net service name is incorrectly specified

usually means that DBD::Oracle can find the listener but the it cannot connect to the DB because the listener cannot find the DB you asked for.

=head2 Oracle utilities

If you are still having problems connecting then the Oracle adapters
utility may offer some help. Run these two commands:

  $ORACLE_HOME/bin/adapters
  $ORACLE_HOME/bin/adapters $ORACLE_HOME/bin/sqlplus

and check the output. The "Protocol Adapters" should include at least "IPC Protocol Adapter" and "TCP/IP
Protocol Adapter".

If it generates any errors which look relevant then please talk to your
Oracle technical support (and not the dbi-users mailing list).

=head2 Connecting using a bequeather

If you are using a bequeather to connect to a server
on the same host as the client, you might have 
to add 

    bequeath_detach = yes

to your sqlnet.ora file or you won't be able to safely use fork/system
functions in Perl.

See the discussion at
L<http://www.nntp.perl.org/group/perl.dbi.dev/2012/02/msg6837.html>
and L<http://www.nntp.perl.org/group/perl.dbi.users/2009/06/msg34023.html>
for more gory details.

=head1 USING THE LONG TYPES

Some examples related to the use of LONG types are available in
the C<examples/> directory of the distribution.

=head1 LINUX

=head2 Installing with Instantclient .rpm files.

Nothing special with this you just have to set up you permissions as follows;

1) Have permission for RWE on '/usr/lib/oracle/10.2.0.3/client/' or the other directory where you RPMed to

2) Set export ORACLE_HOME=/usr/lib/oracle/10.2.0.3/client

3) Set export LD_LIBRARY_PATH=$ORACLE_HOME/lib

4) If you plan to use tnsnames to connect to remote servers and your tnsnames.ora file is not in $ORACLE_HOME/network/admin, you will need to Export TNS_ADMIN=dir to point DBD::Oracle to where your tnsnames.ora file is

=head2 undefined symbol: __cmpdi2 comes up when Oracle isn't properly linked to the libgcc.a library.

In version 8, this was correctd by changing the SYSLIBS entry in
$ORACLE_HOME/bin/genclntsh to include
"-L/usr/lib/gcc-lib/i386-redhat-linux/3.2 -lgcc".

I had tried this with no success as when this program was then run, the
error "unable to find libgcc" was generated.  Of course, this was the
library I was trying to describe!

It turns out that now it is necessary to edit the same file and append
"`gcc -print-libgcc-file-name`" (including the backquotes!).  If you do
this and then run "genclntsh", the libclntsh is properly generated and
the linkage with DBD::Oracle proceeds properly.

=head2 cc1: invalid option `tune=pentium4'" error

If you get the above it seems that eiter your Perl or OS where compiled with a different version of GCC or the GCC that is on your system is very old.

No real problem with the above however you will have to

1) run Perl Makefile.PL

2) edit the Makefile and remove the offending '-mtune=pentium4' text

3) save and exit

4) do the make install and it should work fine for you

=head2 Oracle 9i Lite 

The advice is to use the regular Oracle9i not the lite version. 

Another great source of help was: http://www.puschitz.com/InstallingOracle9i.html

just getting 9i and 9i lite installed.  I use fvwm2(nvidia X driver) as
a window manager which does not work with the 9i install program, works
fine with the default Gnomish(nv X driver), it could have been the X
driver too.

With Redhat9 it is REAL important to set LD_ASSUME_KERNEL to 2.4.1.

I didn't try this but it may be possible to install what is needed by
only downloading the first disk saving some 1.3GB of download fun.

I installed a custom install from the client group.  The packages I
installed are the Programmers section and sqlplus.  I noticed that the
Pro*C when on as a result of the checking the Programmers section I
assume.

Once Oracle was installed properly the DBD::Oracle install went as
smooth as just about every other CPAN module.

=head2 Oracle 10g Instantclient

The Makefile.PL will now work for  Oracle 10g Instantclient. To have both the Compile and
the test.pl to work you must first have the LD_LIBRARY_PATH correctly set to your 
"instantclient" directory. (http://www.oracle.com/technology/tech/oci/instantclient/instantclient.html) 

The present version of the make creates a link on your "instantclient" directory as follows
"ln -s libclntsh.so.10.1 libclntsh.so". It is needed for both the makefile creation and the compile 
but is not need for the test.pl. It should be removed after the compile.

If the Makefile.PL or make fails try creating this link directly in your "instantclient" directory.

=head2 Oracle Database 10g Express Edition  10.2

To get 10Xe to compile correctly I had to add $ORACLE_HOME/lib to the LD_LIBRARY_PATH 
as you would for an install against 10g Standard Edition, Standard Edition One, or 
Enterprise Edition 

=head2 UTF8 bug in Oracle  9.2.0.5.0 and 9.2.0.7.0

DBD::Oracle seems to hit some sort of bug with the above two versions of DB.
The bug seems to hit when you when the Oracle database charset: US7ASCII and the Oracle nchar charset: AL16UTF16 and it has also
been reported when the Oracle database charset: WE8ISO8850P1 Oracle nchar charset: AL32UTF16.  

So far there is no patch for this but here are some work arounds 

    use DBD::Oracle qw( SQLCS_IMPLICIT SQLCS_NCHAR );
    ...
    $sth->bind_param(1, $value, { ora_csform => SQLCS_NCHAR });

    or this way

    $dbh->{ora_ph_csform} = SQLCS_NCHAR; # default for all future placeholders

    or this way

    utf8::downgrade($parameter, 1);

=head1 CYGWIN

Makefile.PL should find and make use of OCI include
files, but you have to build an import library for
OCI.DLL and put it somewhere in library search path.
one of the possible ways to do this is issuing command

    dlltool --input-def oci.def --output-lib liboci.a

in the directory where you unpacked DBD::Oracle distribution
archive.  this will create import library for Oracle 8.0.4.

Note: make clean removes '*.a' files, so put a copy in a safe place.

=head2 Compiling DBD::Oracle using the Oracle Instant Client, Cygwin Perl and gcc

=over

=item 1

Download these two packages from Oracle's Instant Client for
Windows site
(http://www.oracle.com/technology/software/tech/oci/instantclient/htdocs/winsoft.html):

Instant Client Package - Basic: All files required to run OCI,
OCCI, and JDBC-OCI applications

Instant Client Package - SDK: Additional header files and an
example makefile for developing Oracle applications with Instant Client

(I usually just use the latest version of the client)

=item 2

Unpack both into C:\oracle\instantclient_11_1

=item 3

Download and unpack DBD::Oracle from CPAN to some place with no
spaces in the path (I used /tmp/DBD-Oracle) and cd to it.

=item 4

Set up some environment variables (it didn't work until I got the
DSN right):

      ORACLE_DSN=DBI:Oracle:host=oraclehost;sid=oracledb1
      ORACLE_USERID=username/password

=item 5

      perl Makefile.PL
      make
      make test
      make install

=back

Note, the TNS Names stuff doesn't always seem to work with the instant
client so Perl scripts need to explicitly use host/sid in the DSN, like
this:

    my $dbh = DBI->connect('dbi:Oracle:host=oraclehost;sid=oracledb1',
    'username', 'password');

=head2 SUN

If you get this on a Solaris 9 and 10 box

  "Outofmemory!
   Callback called exit.
   END failed--call queue aborted."

The solution may be as simple as not having you "ORACLE_HOME" Defined in the
environment.

It seems that having it defined will prevent the error.

=head2 VMS

This is related to Oracle RDBMS 9.2 and later, since Oracle 
made fundamental changes to oracle installation requirements 
and factual installation with this release.

Oracle's goal was to make VMS installation be more like on
*nix and Windows, with an all new Oracle Home structure too,
requiring an ODS-5 disk to install Oracle Home on instead of
the good old ODS-2.

Another major change is the introduction of an Oracle generated
logical name table for oracle logical names like ORA_ROOT and all
its derivatives like ORA_PROGINT etc. And that this logical name
table is inserted in LNM$FILE_DEV in LNM$PROCESS_DIRECTORY.

    (LNM$PROCESS_DIRECTORY)

    "LNM$FILE_DEV" = "SERVER_810111112"
            = "LNM$PROCESS"
            = "LNM$JOB"
            = "LNM$GROUP"
            = "LNM$SYSTEM"
            = "DECW$LOGICAL_NAMES"

This ensures that any process that needs to have access to 
oracle gets the environment by just adding one logical name table
to a central process specific mechanism.

But as it is inserted at the very top of LNM$FILE_DEV it also
represents a source of misfortune - especially if a user with
enough privilege to update the oracle table does so (presumably
unintentionally), as an examble by changing NLS_LANG.

PERL has the abillity to define, redefine and undefine (deassign)
logical names, but if not told otherwise by the user does it
in the first table in above list, and not as one would normally
expect in the process table.

Installing DBI and DBD::Oracle has influence upon this since in
both cases a few environment variables are read or set in the
test phase.
For DBI it is the logical SYS$SCRATCH, which is a JOB logical.
For DBD-Oracle it is when testing a new feature in the Oracle 
RDBMS: UTF8 and UTF16 character set functionality, and in order 
to do this it sets and unsets the related environment variables 
NLS_NCHAR and NLS_LANG.

If one is not careful this changes the values set in the oracle 
table - and in the worst case stays active until the next major 
system reset. It can also be a very hard error to track down 
since it happens in a place where one normally never looks.

Furthermore, it is very possibly that some or all of the UTF tests
fails, since if one have a variable like NLS_LANG in his process
table, then even though 'mms test' sets it in the wrong table
it is not invoked as it is overruled by the process logical...

The way to ensure that no logicals are set in the oracle table and
that the UTF tests get the best environment to test in, and that 
DBI correctly translates the SYS$SCRATCH logical, use the
logical

      PERL_ENV_TABLES

to ensure that PERL's behavior is to leave the oracle table alone and
use the process table instead:

      $ DEFINE PERL_ENV_TABLES LNM$PROCESS, LNM$JOB

This tells PERL to use the LNM$PROCESS table as the default place to
set and unset variables so that only the perl users environment
is affected when installing DBD::Oracle, and ensures that the
LNM$JOB table is read when SYS$SCRATCH is to be translated.

PERL_ENV_TABLES is well documented in the PERLVMS man page.

Oracle8 releases are not affected, as they don't have the 
oracle table implementation, and no UTF support.

Oracle 9.0 is uncertain, since testing has not been possible yet,
but the remedy will not hurt :)

=head1 Miscellaneous

=head2 Crash with an open connection and Module::Runtime in mod_perl2

See RT 72989 (https://rt.cpan.org/Ticket/Display.html?id=72989)

Apache2 MPM Prefork with mod_perl2 will crash if Module::Runtime is
loaded, and an Oracle connection is opened through PerlRequire (before
forking).

It looks like this was fixed in 0.012 of Module::Runtime.

=head1 AUTHORS

=over 4

=item *

Tim Bunce <timb@cpan.org>

=item *

John Scoles

=item *

Yanick Champoux <yanick@cpan.org>

=item *

Martin J. Evans <mjevans@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 1994 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

