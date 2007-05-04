In general compiling DBD:Oracle for 64 bit machines has been a hit or miss operation.  
The main thing to remember is you will have to compile using 32 bit Perl and compile DBD::Oracle against a 32bit client
which sort of defeats the purpose of having a 64bit box.  
So until 64bit Perl comes out we will be posing in this README any success stories we have come across


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


