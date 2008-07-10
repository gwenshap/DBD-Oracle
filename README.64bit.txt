In general compiling DBD:Oracle for 64 bit machines has been a hit or miss operation.  
The main thing to remember is you will have to compile using 32 bit Perl and compile DBD::Oracle against a 32bit client
which sort of defeats the purpose of having a 64bit box.  
So until 64bit Perl comes out we will be posing in this README any success stories we have come across

-------- Original Message --------

Subject:   Building 32bit DBD::Oracle against 64bit Oracle
From:  Dennis Reso
Date:   7/9/2008 5:44 PM
Priority:   Normal 

Building DBD::Oracle v1.21 against Perl 5.8.5 Oracle 9.2.0.4 Solaris 8

Got the dreaded "wrong ELF class" when the Oracle.so ends up built
against the 64bit library instead of the one in $ORACLE_HOME/lib32.
Use 'dump -vL Oracle.so' to see the internalized RPATH definition.

Tried the following solution, widely posted, without success:

  perl Makefile.PL -m $ORACLE_HOME/rdbms/demo/demo_rdbms32.mk

What worked for me (pass the LIBDIR to the Oracle make process):

  export ORACLE_HOME=/apps/Oracle9.2.0.4
  export LD_LIBRARY_PATH=$ORACLE_HOME/lib32
  perl -pi -e 's/CC=true/CC=true LIBDIR=lib32/' Makefile.PL
  perl Makefile.PL -m $ORACLE_HOME/rdbms/demo/demo_rdbms32.mk
  make

The LIBDIR= is defined in $ORACLE_HOME/rdbms/lib/env_rdbms.mk which
also includes a REDEFINES32= that overrides it, but is only used by
the $ORACLE_HOME/rdbms/lib/ins_rdbms.mk.  Oracle bug?

Also repeated the same failure and success with
  Oracle 9.2.0.8 Solaris 10
  Oracle 10.2.0.3 Solaris 10

Seems fixed in demo_rdbms32.mk (no Makefile.PL edit needed ) as of
  Oracle 10.2.0.4 Solaris 10

Probably also fixed in some patchset newer than 9.2.0.4.

-- 
Dennis Reso <dreso (at) comcast.net> 

-------- Original Message --------

Subject:   DBD::Oracle 64-bit success story 
From:   H.Merijn Brand
Date:   On Mon, 14 Apr 2008 09:48:41
Priority:   Normal 

I finally got round trying Oracle Instant Client on Linux with no
Oracle installed, connecting to a 64bit Oracle 9.2.0.8 on HP-UX
11.11/64. I had to do some fiddling with Makefile.PL (see bottom).
Sorry for this being long. Feel free to mold it into anything useful.

1. Before you start on DBD::Oracle, make sure DBD::ODBC works. That will
   assure your DSN works. Install unixODBC before anything else.

2. Assuming you've got OIC from the rpm's, you will have it here:

   /usr/include/oracle/11.1.0.1/client
   /usr/lib/oracle/11.1.0.1/client
   /usr/share/oracle/11.1.0.1/client
   

3. for the 64 bit clienat we have these rpm   
     oracle-instantclient-basic-11.1.0.1-1.x86_64.rpm
      oracle-instantclient-devel-11.1.0.1-1.x86_64.rpm
      oracle-instantclient-jdbc-11.1.0.1-1.x86_64.rpm
      oracle-instantclient-odbc-11.1.0.1-1.x86_64.rpm
      oracle-instantclient-sqlplus-11.1.0.1-1.x86_64.rpm
   
      and to add to the confusement, they install to
   
      /usr/include/oracle/11.1.0.1/client64
      /usr/lib/oracle/11.1.0.1/client64
      /usr/share/oracle/11.1.0.1/client64

4. To make DBD::ODBC work, I had to create a tnsnames.ora, and I chose

   /usr/lib/oracle/11.1.0.1/admin/tnsnames.ora

   /usr/lib/oracle/11.1.0.1/admin > cat sqlnet.ora
   NAMES.DIRECTORY_PATH = (TNSNAMES, ONAMES, HOSTNAME)
   /usr/lib/oracle/11.1.0.1/admin > cat tnsnames.ora
   ODBCO = (
     DESCRIPTION =
     ( ADDRESS_LIST =
       ( ADDRESS =
     ( PROTOCOL        = TCP           )
     ( PORT            = 1521          )
     ( HOST            = rhost         )
     )
       )
     ( CONNECT_DATA =
       ( SERVICE_NAME      = odbctest      )
       )
     )
   /usr/lib/oracle/11.1.0.1/admin >

   Real world example changed to hide the obvious. Important bits are
   "ODBCO", which is the ODBC name, and it can be anything, as long as
   you use this in ORACLE_DSN too (please don't use whitespace, colons,
   semicolons and/or slashes. "rhost" is the hostname of where the DB
   is running, and "odbctest" is available on "rhost". To check that,
   run "lsnrctl services" on "rhost".
   Set the environment (TWO_TASK is not needed)
   
   > setenv LD_LIBRARY_PATH /usr/lib/oracle/11.1.0.1/client/lib
   > setenv TNS_ADMIN       /usr/lib/oracle/11.1.0.1/admin
   > setenv ORACLE_HOME     /usr/lib/oracle/11.1.0.1/client
   > setenv ORACLE_DSN      dbi:Oracle:ODBCO
   > setenv ORACLE_USERID   ORAUSER/ORAPASS

   Check if the connection works:
   > isql -v ODBCO

   And for Oracle:
   > sqlplus ORAUSER/ORAPASS@ODBCO
   and
   > sqlplus ORAUSER/ORAPASS@rhost/odbctest

   should both work


Note by JPS:

Merijn patched the trunk version of Makeifle.PL to account for the above it will be in release 1.22

-------- Original Message --------

Subject:   DBD::Oracle 64-bit success story 
From:   "QiangLi" <qiangli@yorku.ca> 
Date:   Thu, March 6, 2008 5:25 pm 
To:   pause@pythian.com 
Priority:   Normal 

hi,

thanks for maintaining DBD::Oracle. I have installed DBD::Oracle against 
  64-bit oracle 10g on a 64-bit solaris machine. maybe worth another 
entry for the README.64bit.txt file.

i am using gcc from sun freesoftware and also SUNWbinutils which 
contains the gas (gnu assembler)

here is the steps with comment:

# set install target
% /usr/perl5/5.8.4/bin/perlgcc Makefile.PL PREFIX=/var/tmp/lib

# since our perl is 32-bit, we can't build it against a 64bit oracle 
install.
# edit Makefile and change reference to oracle's "lib/" to "lib32/"
% perl -pi -e 's/oracle_home\/lib/oracle_home\/lib32/g' Makefile
% perl -pi -e 's/oracle_home\/rdbms\/lib/oracle_home\/rdbms\/lib32/g' 
Makefile

% make

# ignore error like  ORA-12162: TNS:net service name is incorrectly 
specified...
% make test

% make install

# does it work.
% perl -I'/var/tmp/lib/lib/site_perl/5.8.4/sun4-solaris-64int/' 
-MDBD::Oracle -e1

cheers,

Qiang




-------- Original Message --------
Subject:     Tip: Compiling 32bit modules against 64bit Oracle 10g on solaris
Date:     Thu, 1 Nov 2007 16:41:28 -0400
From:     Edgecombe, Jason <jwedgeco@uncc.edu>
To:     <pause@pythian.com>
CC:     <cartmanltd@hotmail.com>



Hi There,

I just wanted to thank both of you.

The tip from cartmanltd@hotmail.com was the trick for getting
DBD::Oracle compiled in 32bit format against the Oracle 10g client on
solaris.

Here was the command that worked:
  perl Makefile.PL -m $ORACLE_HOME/rdbms/demo/demo_rdbms32.mk

Even though the tip was for aix, it fixed my build issue on solaris 9
(sparc)

I've been banging my head on this problem for a few days.

Thanks,
Jason

Jason Edgecombe
Solaris & Linux Administrator
Mosaic Computing Group, College of Engineering
UNC-Charlotte
Phone: (704) 687-3514



Source:Tom Reinertson
Platform:Amd64
OS:Gentoo-amd64

The following instructions work for dbd::oracle 1.19 on a gentoo-amd64 installation. 

1) install the oracle libraries 

	Strictly speaking you only need dev-db/oracle-instantclient-basic
	for dbd::oracle, but i always like to have sql*plus lying around,
	which requires the basic package, so i just install sql*plus.

	emerge dev-db/oracle-instantclient-sqlplus which also pulls in
	dev-db/oracle-instantclient-basic.  these packages are fetch
	restricted so you will be required to follow the download instructions.
	following these instructions, you should have retrieved these packages:

	instantclient-basic-linux-x86-64-10.2.0.3-20070103.zip
	instantclient-sdk-linux-x86-64-10.2.0.3-20070103.zip
	instantclient-sqlplus-linux-x86-64-10.2.0.3-20070103.zip

	now move them into the /usr/portage/distfiles directory.

	you should now be able to emerge dev-db/oracle-instantclient-sqlplus.

2) install DBD::Oracle

	issue the command:

		perl -MCPAN -e'install DBD::Oracle'

	this fails with the following error:

		x86_64-pc-linux-gnu-gcc: unrecognized option '-wchar-stdc++'
		x86_64-pc-linux-gnu-gcc: unrecognized option '-cxxlib-gcc'
		cc1: error: /ee/dev/bastring.h: No such file or directory

	find the offending files in your cpan directory:
		{~/.cpan/build/DBD-Oracle-1.19} grep -lr cxxlib *
		Makefile
		blib/arch/auto/DBD/Oracle/mk.pm
		mk.pm

	edit these files and remove the two invalid options and the include of bastring.h.

	now build the module:

		perl Makefile.PL -l
		make
		# make test generates lots of errors
		make test
		make install

	you should now be ready to run.


