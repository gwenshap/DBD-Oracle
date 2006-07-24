From SRS0=uAXy=PG=zorranlabs.com=alexzar@bounce2.pobox.com  Wed Dec 22 08:11:00 2004
Received: from localhost (localhost [IPv6:::1])
	by dansat.data-plan.com (8.13.1/8.13.1) with ESMTP id iBM8Aog0091816
	for <timbo@localhost>; Wed, 22 Dec 2004 08:11:00 GMT
	(envelope-from SRS0=uAXy=PG=zorranlabs.com=alexzar@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-6.2.5)
	for timbo@localhost (single-drop); Wed, 22 Dec 2004 08:11:00 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1Ch0it-0001A5-Rv;
	Wed, 22 Dec 2004 07:15:51 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1Ch0it-0001A5-Rv
	for pobox@data-plan.com; Wed, 22 Dec 2004 07:15:51 +0000
Received: from [208.58.1.198] (helo=lime.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1Ch0is-0000To-R8
	for pobox@data-plan.com; Wed, 22 Dec 2004 07:15:51 +0000
Received: from lime.pobox.com (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id F0F0DFE10C;
	Wed, 22 Dec 2004 02:15:49 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from lime (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id 8B2AAFE1C3
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 22 Dec 2004 02:15:49 -0500 (EST)
Received-SPF: none (lime.pobox.com: domain of alexzar@zorranlabs.com does not designate permitted sender hosts)
Received: from penguin.nocdirect.com (penguin.nocdirect.com [69.73.160.206])
	by lime.pobox.com (Postfix) with ESMTP id 2B41BFE159
	for <Tim.Bunce@pobox.com>; Wed, 22 Dec 2004 02:13:17 -0500 (EST)
Received: from localhost ([127.0.0.1])
	by penguin.nocdirect.com with esmtps (TLSv1:DES-CBC3-SHA:168)
	(Exim 4.43)
	id 1Cgz53-0000fj-Bx; Tue, 21 Dec 2004 23:30:37 -0600
Date: Tue, 21 Dec 2004 23:30:35 -0600 (CST)
From: Alex Zarutin <alexzar@zorranlabs.com>
X-X-Sender: zorranla@penguin.nocdirect.com
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: dbi-users-help@perl.org
Subject: Step-by-Step installation manual of DBD-Oracle-1.16 on Sparc Solaris
 9 with Oracle 9.2.0.1.0 client.
Message-ID: <Pine.LNX.4.44.0412212325150.1522-100000@penguin.nocdirect.com>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; charset=US-ASCII
X-AntiAbuse: This header was added to track abuse, please include it with any abuse report
X-AntiAbuse: Primary Hostname - penguin.nocdirect.com
X-AntiAbuse: Original Domain - pobox.com
X-AntiAbuse: Originator/Caller UID/GID - [47 12] / [47 12]
X-AntiAbuse: Sender Address Domain - zorranlabs.com
X-Source: 
X-Source-Args: 
X-Source-Dir: 
Status: RO
X-Status: A
Content-Length: 15603
Lines: 426


Hi Tim,
 
I have spent a couple days trying to install DBD-Oracle-1.16 (all
required stuff, such as GCC, DBI, etc has been installed before ) on
Sun-Fire v240 running Spark Solaris 9 with the Oracle 9.2.0.1.0 client
installed. The installation takes a couple minutes ONLY after you spend
days trying to make it workable.
 
I wrote the log of what I do, in order to do not waste my time in
future. I am pretty sure that this log will be very useful for people
installing DBD-Oracle on Solaris. I published it on my log page, and left 
link on it at http://cpanratings.perl.org/d/DBD-Oracle review page. I 
would recommend you to add this log to the readme file of your next 
releases. Log is written very detailed (step-by-step) with highlighted 
typical mistakes.  
 
Environment:
Hardware/OS: bash-2.05# uname -a
SunOS qadmz41 5.9 Generic_117171-08 sun4u sparc SUNW,Sun-Fire-V240 
OS is actually "standard" Solaris 9 installation came on the box from
SUN
 
Oracle Client: Oracle 9.2.0.1.0
GCC: gcc version 3.3.2, installed to /usr/local/bin as a package from
http://www.sunfreeware.com/programlistsparc9.html
PERL: perl v5.8.5 built for sun4-solaris, installed to /usr/local/bin as
a package from http://www.sunfreeware.com/programlistsparc9.html    
DBI: DBI-1.45, installed from http://search.cpan.org/~timb/DBI-1.45/
 
Step-by-Step Manual:
 
Step 1: In order to install "DBD-Oracle-1.16" you need to download it,
set all appropriate environment variables (see readme for details) and
run <<perl Makefile.PL>>. 
I got an error that is mostly typical for Solaris installation:
 
// ************************ Error 1 ***********************/
 
....
Found header files in rdbms/demo.

*********************************************************
I can't find the header files I need in your Oracle installation.
You probably need to install some more Oracle components.
I'll keep going, but the compile will probably fail.
See README.clients for more information.
*********************************************************
Checking for functioning wait.ph
 
System: perl5.008005 sunos 5.9 generic sun4u sparc sunw,ultra-5_10
solaris
Compiler:   gcc -B/usr/ccs/bin/ -O -fno-strict-aliasing -pipe
-I/usr/local/include -I/opt/gnu/include -D_LARGEFILE_SOURCE
-D_FILE_OFFSET_BITS=64

....
// *****************************************************/
 
Investigating this problem, I found that error message is thrown by the
"find_headers" sub of Makefile.PL, especially in this "if
(!$h_file{'oratypes.h'} || !$h_file{'ocidfn.h'})" evaluation. 
So I checked these files to make sure that they are installed, but did
not find them under $ORACLE_HOME/rdbms 
In the same time, I found an article saying about the similar problem
with DBD-Oracle on Linux,
http://baroti.homedns.org/steve/lost+found/cpan-install-DBD-Oracle-9-2-l
inux.html
They mentioned about two files, and since I was not sure about second
one, ociapr.h I copied both files. You should find its public.1.1.jar
file on the Disk3 of Oracle 9i installation set.
      
bash-2.05# pwd
/ora_orig/Disk3/stage/Components/oracle.rdbms.oci/9.2.0.1.0/1/DataFiles
 
bash-2.05# ls -al
total 970
drwxr-xr-x   2 2840     42424        512 Aug 21  2002 .
drwxr-xr-x   3 2840     42424        512 Aug 21  2002 ..
-rwxr-xr-x   1 2840     42424       2047 May  9  2002 bin.1.1.jar
-rwxr-xr-x   1 2840     42424        206 May  9  2002 build.1.1.jar
-rwxr-xr-x   1 2840     42424     135034 May  9  2002 demo.1.1.jar
-rwxr-xr-x   1 2840     42424     329814 May  9  2002 public.1.1.jar
 
You should just (as dba:oracle) to create the directory called public,
copy public.1.1.jar there and extract all files, since I would not guess
if the rest of them are used or not
 
bash-2.05# mkdir $ORACLE_HOME/rdbms/public
 
bash-2.05# ls -al $ORACLE_HOME/rdbms/public
total 3404
drwxr-xr-x   2 oracle   dba          512 Dec 21 12:12 .
drwxr-xr-x  10 oracle   dba          512 Dec 21 12:05 ..
...
-rw-r--r--   1 oracle   dba         6055 Mar  9  2002 ociapr.h
-rw-r--r--   1 oracle   dba        10694 Jun 29  2000 ocidfn.h
...

After that run <<perl Makefile.PL>> again, and I hope process passes
fine. At least, it was fine in my case 
 
Step 2: You should <<make>> the module, and as it appears on Solaris,
you will get typical problem. See my error log:
 
// ************************ Error 2 ***********************/
....
rm -f blib/arch/auto/DBD/Oracle/Oracle.so
LD_RUN_PATH="/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32:
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/rdbms/lib32" gcc
-B/usr/ccs/bin/  -G -L/usr/local/lib -L/opt/gnu/lib Oracle.o  dbdimp.o
oci8.o -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib -laio
-lposix4  -lm  -lthread -o blib/arch/auto/DBD/Oracle/Oracle.so
ld: fatal: file
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib//libclntsh.so:
wrong ELF class: ELFCLASS64
ld: fatal: File processing errors. No output written to
blib/arch/auto/DBD/Oracle/Oracle.so
collect2: ld returned 1 exit status
*** Error code 1
make: Fatal error: Command failed for target
`blib/arch/auto/DBD/Oracle/Oracle.so'

// *****************************************************/
 
So, as another set on Google' posts showed that it is a possibility of
missing libraries compiled with 64 bits and same libraries compiled with
32 bits suppoert. As I understood, all components of installation, such
as Oracle client, Perl, GCC should support only one type of libraries,
either 32 or 64 bits. I found that having all as 32 bits is easier to me
than recompile perl, gcc as 64 (may be I am wrong in this assumption).
In order to have all of them as 32 bits, I changed lib to lib32 in
Manifest file (not Manifest.PL). 
 
You should replace the following lines in the "MakeMaker const_loadlibs
section":
 
EXTRALIBS =  -L$(LIBHOME) -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib -laio
-lposix4  -lm  -lthread
LD_RUN_PATH=/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32:/
export/home/oracle/u01/app/oracle/product/9.2.0.1.0/rdbms/lib32

By their lib32 clones:
 
EXTRALIBS =  -L$(LIBHOME) -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32 -laio
-lposix4  -lm  -lthread
LD_RUN_PATH=/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32:/
export/home/oracle/u01/app/oracle/product/9.2.0.1.0/rdbms/lib32

And replace this line in "MakeMaker dynamic_lib section" (~~ line 491)
 
OTHERLDFLAGS =  -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib -laio
-lposix4  -lm  -lthread

By its lib32 clone:
 
OTHERLDFLAGS =  -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32 -laio
-lposix4  -lm  -lthread

I hope, that after that process passes without any errors. Here is last
part, that I got during <<make>>:
 
.....
rm -f blib/arch/auto/DBD/Oracle/Oracle.so
LD_RUN_PATH="/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32:
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/rdbms/lib32" gcc
-B/usr/ccs/bin/  -G -L/usr/local/lib -L/opt/gnu/lib Oracle.o  dbdimp.o
oci8.o -xarch=v9
-L/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ -lclntsh
`cat /export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/ldflags`
`cat
/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32/sysliblist`
-R/export/home/oracle/u01/app/oracle/product/9.2.0.1.0/lib32 -laio
-lposix4  -lm  -lthread -o blib/arch/auto/DBD/Oracle/Oracle.so
chmod 755 blib/arch/auto/DBD/Oracle/Oracle.so
cp Oracle.bs blib/arch/auto/DBD/Oracle/Oracle.bs
chmod 644 blib/arch/auto/DBD/Oracle/Oracle.bs
/usr/local/bin/perl "-Iblib/arch" "-Iblib/lib" ora_explain.PL
ora_explain
Extracted ora_explain from ora_explain.PL with variable substitutions.
cp ora_explain blib/script/ora_explain
/usr/local/bin/perl "-MExtUtils::MY" -e "MY->fixin(shift)"
blib/script/ora_explain
Manifying blib/man1/ora_explain.1
Manifying blib/man3/DBD::Oracle.3
Manifying blib/man3/DBD::Oraperl.3
 
III. Once we build the module, we should test it, to make sure that it
works fine. You should run <<make test>> to do it:
 
Check that you have ORACLE_HOME, ORACLE_USERID, ORACLE_SID environment
variables set, like this:
 
ORACLE_HOME=="/export/home/oracle/u01/app/oracle/product/9.2.0.1.0
ORACLE_USERID=STARSHIP/STARSHIP
ORACLE_SID=COLORADO

When you run <<make test>>, you will probably get this errors:
 
// ************************ Error 3 ***********************/
 
bash-2.05# make test
PERL_DL_NONLAZY=1 /usr/local/bin/perl "-MExtUtils::Command::MM" "-e"
"test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
t/01base................ok
t/10general.............DBI connect('','STARSHIP/STARSHIP',...) failed:
ORA-12545: Connect failed because target host or object does not exist
(DBD ERROR: OCIServerAttach) at t/10general.t line 12
Undefined subroutine &main::BAILOUT called at t/10general.t line 15.
# Looks like your test died before it could output anything.
t/10general.............dubious
        Test returned status 255 (wstat 65280, 0xff00)
DIED. FAILED tests 1-31
        Failed 31/31 tests, 0.00% okay
.....
 
// *****************************************************/
 
One more brainstorm, and I figured out another way to set ORACLE_USERID:
 
ORACLE_USERID=STARSHIP/STARSHIP@COLORADO
ORACLE_SID=COLORADO

Later, when tests finished, I was confirmed that it was probably
preferred way of setting ORACLE_USERID. 
Tests did found correct settings, and "main" set of them returned the
following report: 
 
All tests successful, 1 test and 122 subtests skipped.
Files=18, Tests=1020, 24 wallclock secs (11.27 cusr +  1.34 csys = 12.61
CPU)
 
For the Extra test, less formal, but test anyway, I just commented these
two lines in test.pl file
 
$dbname = $ARGV[0] || ''; # if '' it'll use TWO_TASK/ORACLE_SID
$dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
 
and set the same values in the same form to the $dbuser as it was in
ORACLE_USERID <mailto:ORACLE_USERID=STARSHIP/STARSHIP@COLORADO>  , and
left $dbname empty,  

$dbname = ''; 
$dbuser = 'STARSHIP/STARSHIP@COLORADO';
 
and got pretty good report:
 
Connecting
 to '' (from command line, else uses ORACLE_SID or TWO_TASK -
recommended)
 as 'STARSHIP/STARSHIP@COLORADO' (via ORACLE_USERID env var or default -
recommend name/passwd@dbname)
(ORACLE_SID='', TWO_TASK='')
Fields:    6
Names:     'NUM_T'      'DATE_T'        'CHAR_T'        'ROWID_T'
'RAW_T' 'NULL_T'
Lengths:   172  76      121     21      3       1
OraTypes:  2    12      1       104     23      1
SQLTypes:  8    93      12      -9104   -2      12
Scale:     0    0       0       0       0       0
Precision: 126  75      120     20      2       0
Nullable:  1    1       1       1       1       1
Est row width:    32
Data rows:
    fetch: '7.2', '21-DEC-04', 'STARSHIP', 'AAAADeAABAAAAZSAAA', '7D',
undef
 
ora_logoff...
lda out of scope...
 
Testing repetitive connect/open/close/disconnect:
If this test hangs then read the README.help file.
Expect sequence of digits, no other messages:
1 2 3 4 5
 
Test interaction of explicit close/logoff and implicit DESTROYs
Expect just 'done.', no other messages:
done.
 
Testing row cache (5).
Test completed in 0 seconds.
 
Test complete (0 seconds).
If the tests above have produced the 'expected' output then they have
passed.
 
IV. The last part is actually target of all steps above, installing
build module. <<make install> did not surprise me, and it it passed
smoothly.
 
bash-2.05# make install
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/dbdimp
.h
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/ocitra
ce.h
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/Oracle
.h
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/mk.pm
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/Oracle
.so
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/Oracle
.bs
Files found in blib/arch: installing files in blib/lib into architecture
dependent library tree
Installing /usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/oraperl.ph
Installing /usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/Oraperl.pm
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/DBD/Oracle.pm
Installing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/DBD/Oracle/GetInfo.pm
Installing /usr/local/share/man/man1/ora_explain.1
Installing /usr/local/share/man/man3/DBD::Oracle.3
Installing /usr/local/share/man/man3/DBD::Oraperl.3
Installing /usr/local/bin/ora_explain
Writing
/usr/local/lib/perl5/site_perl/5.8.5/sun4-solaris/auto/DBD/Oracle/.packl
ist
Appending installation info to
/usr/local/lib/perl5/5.8.5/sun4-solaris/perllocal.pod

V. This is actually it, and you do not need to do anything else. But
investigating different errors during the various steps, I found the
very simple "independent sanity" testdbi perl script written by Jeff
Hunter. This script is not related to standard process of
making/buildin/testing/installation. It just verifies that you can
access DB and run a couple queries against it. The code itself,
testdbi.pl can be found at
http://www.idevelopment.info/data/Oracle/DBA_tips/Programming/PROGRAMMIN
G_2.shtml
 
You just should set connection information, similar to how I did it, 
 
  $ORACLE_SID                = "COLORADO";
  $ORACLE_USERID           = "STARSHIP";
  $ORACLE_PASSWORD      = "STARSHIP";
 
  $ENV{'ORACLE_SID'}       = "$ORACLE_SID";
  $ENV{'ORACLE_HOME'}    = /u01/app/oracle/product/9.2.0.1.0";
 
run it as any perl script, <<perl testdbi.pl>>, and see result:
 
bash-2.05# perl testdbi.pl
 
Running testdbi.pl...
 
  (*) Attempting Oracle Login ...
      OK
  (*) Creating table TEST_DBI ...
      OK
  (*) Insert into TEST_DBI ...
      1 rows inserted.
      1 rows inserted.
      1 rows inserted.
      OK
  (*) Select from TEST_DBI ...
 
        --> TEST_DBI_INTR_NO :  1000
        --> TEST_DBI_NAME    :  Jeff Hunter

        --> TEST_DBI_INTR_NO :  1001
        --> TEST_DBI_NAME    :  Melody Hunter

        --> TEST_DBI_INTR_NO :  1002
        --> TEST_DBI_NAME    :  Alex Hunter
      OK
 
  (*) Delete from TEST_DBI ...
      3 rows deleted.
      OK
 
  (*) Drop table TEST_DBI ...
      OK
 
  (*) Select USER and SYSTEM ...
 
        --> USER             :  STARSHIP
        --> SYSDATE          :  21-DEC-2004 16:49:59
      OK
 
  (*) Attempting Oracle Logoff ...
      OK
 
Ending testdbi.pl...

With the best regards,
 
Alex Zarutin

Software Engineer 
4thpass A Motorola Company 
Seattle, WA  
www.4thpass.com 

 


