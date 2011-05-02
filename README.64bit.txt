In general compiling DBD:Oracle for 64 bit machines has been a hit or miss operation.  
The main thing to remember is you will have to compile using 32 bit Perl and compile DBD::Oracle against a 32bit client
which sort of defeats the purpose of having a 64bit box.  
So until 64bit Perl comes out we will be posing in this README any success stories we have come across


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


