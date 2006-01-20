From: William Fishburne <william.fishburne@verizon.net>
Date: Tue, 20 May 2003 09:22:30 -0400

undefined symbol: __cmpdi2 comes up when Oracle isn't properly linked
to the libgcc.a library.

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



From: Brent LaVelle <brentlavelle@yahoo.com>
Date: Tue, 2 Sep 2003 11:07:47 -0700 (PDT)
Message-ID: <20030902180747.69838.qmail@web14310.mail.yahoo.com>
Subject: RE: Oracle 9i Lite and DBD::Oracle problems [solved]

With the help of Brian Haas and Ian Harisay I got DBD::Oracle working. 
The advice is to use the regular Oracle9i not the lite version. 
Another great source of help was:
	http://www.puschitz.com/InstallingOracle9i.html
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

I don't know if Oracle is bulletproof on Linux but the install process
has some problems.


From: John Scoles <scoles@pythian.com>
Date: Fri, 29 Sep 2005 10:48:47 -0700 (EST)
Subject: RE: Oracle 10g Instantclient

The Makefile.PL will now work for  Oracle 10g Instantclient. To have both the Compile and
the test.pl to work you must first have the LD_LIBRARY_PATH correctly set to your 
"instantclient" directory. (http://www.oracle.com/technology/tech/oci/instantclient/instantclient.html) 
The present version of the make creates a link on your "instantclient" directory as follows
"ln -s libclntsh.so.10.1 libclntsh.so". It is needed for both the makefile creation and the compile 
but is not need for the test.pl. It should be removed after the compile.
If the Makefile.PL or make fails try creating this link directly in your "instantclient" directory.
 
From: John Scoles <scoles@pythian.com>
Date: Thurs, 19 Jan 2006 11:48:47 -0700 (EST)
Subject: RE: Oracle Database 10g Express Edition  10.2 

To get 10Xe to compile correctly I had to add $ORACLE_HOME/lib to the LD_LIBRARY_PATH 
as you would for an install against 10g Standard Edition, Standard Edition One, or 
Enterprise Edition 
 
