In general compiling DBD:Oracle for 64 bit machines has been a hit or miss operation.  
The main thing to remember is you will have to compile using 32 bit Perl and compile DBD::Oracle against a 32bit client
which sort of defeats the purpose of having a 64bit box.  
So until 64bit Perl comes out we will be posing in this README any success stories we have come across

fyi

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


