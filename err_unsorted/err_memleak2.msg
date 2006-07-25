From mike@boom.net  Fri Nov 28 22:23:33 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hASMLLnY018698
	for <timbo@localhost>; Fri, 28 Nov 2003 22:23:33 GMT
	(envelope-from mike@boom.net)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 28 Nov 2003 22:23:33 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1APmgW-0006iM-9g;
	Fri, 28 Nov 2003 17:45:40 +0000
Received: from [207.8.214.2] (helo=icicle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1APmgW-0006iM-9g
	for pobox@dbi.demon.co.uk; Fri, 28 Nov 2003 17:45:40 +0000
Received: from icicle.pobox.com (localhost[127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id E82CD95E03
	for <pobox@dbi.demon.co.uk>; Fri, 28 Nov 2003 12:45:38 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id B1EE595DFB
	for <Tim.Bunce@pobox.com>; Fri, 28 Nov 2003 12:45:38 -0500 (EST)
Received: from abort.boom.net (abort.boom.net[69.36.241.24])
	by icicle.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Fri, 28 Nov 2003 12:45:38 -0500 (EST)
Received: by abort.boom.net (Postfix, from userid 530)
	id E3C8B8517A; Fri, 28 Nov 2003 09:45:36 -0800 (PST)
Date: Fri, 28 Nov 2003 09:45:36 -0800
From: Mike Hedlund <mike@boom.net>
To: dbi-users@perl.org
Cc: Tim.Bunce@pobox.com
Subject: Memory leak in DBD::Oracle 1.14 ... ?
Message-ID: <20031128174536.GJ10609@boom.net>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.5.4i
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id hASMLLnY018698
Content-Length: 24309
Lines: 434

I've attached a little script which replicates the problem on my machine as well as the build session log for DBD::Oracle 1.14.

I've tested it using DBI 1.38 and DBI 1.28 with both DBD::Oracle 1.12 and 1.14.

Regardless of the DBI version, DBD::Oracle 1.14 leaks on my system and DBD::Oracle 1.12 does not. I've noticed the leak when calling connect_cached(), do() (or prepare()/execute()/commit/finish).

-mike


-------------------- script ---------------
#!/usr/bin/perl
use strict;
use DBI;
                                                                                
my($dbp) = "dbi:Oracle:host=weirdo.com;port=1521;sid=SID";
my($dbu) = "username";
my($dbpass) = "password";
                                                                                
while (1) {
        my($sth);
        my(@row);
        my($dbh) = DBI->connect_cached($dbp,$dbu,$dbpass) || die "Couldn't connect to oracle db: $DBI::errstr\n";
                                                                                
##
## uncomment these and it just leaks faster.
##
#       $sth = $dbh->prepare("SELECT * from FROM_STATS");
#       $sth->execute;
#       while(@row = $sth->fetchrow_array) {
                ##print "row: @row\n";
#       }
#       $sth->finish;
}
exit;
------------------------ end script --------------------


------------ log ---------------------------------------
Script started on Fri 28 Nov 2003 09:11:15 AM PST
[mike@commando DBD-Oracle-1.14]$ setenv ORACLE_HOME /home/orahome
[mike@commando DBD-Oracle-1.14]$ make realclean
rm -f blib/script/ora_explain
rm -rf Oracle.c Oracle.xsi dll.base dll.exp sqlnet.log libOracle.def ora_explain mk.pm ./blib Makefile.aperl blib/arch/auto/DBD/Oracle/extralibs.all perlmain.c tmon.out mon.out so_locations pm_to_blib *.o *.a perl.exe perl perl Oracle.bs Oracle.bso Oracle.def libOracle.def Oracle.exp Oracle.x core core.*perl.*.? *perl.core
mv Makefile Makefile.old > /dev/null 2>&1
rm -rf blib/lib/auto/DBD/Oracle blib/arch/auto/DBD/Oracle
rm -rf DBD-Oracle-1.14
rm -f blib/arch/auto/DBD/Oracle/Oracle.so blib/arch/auto/DBD/Oracle/Oracle.bs
rm -f blib/arch/auto/DBD/Oracle/Oracle.a
rm -f  blib/lib/DBD/Oracle.pm blib/arch/auto/DBD/Oracle/dbdimp.h blib/lib/oraperl.ph
rm -f blib/arch/auto/DBD/Oracle/ocitrace.h blib/lib/Oraperl.pm
rm -f blib/arch/auto/DBD/Oracle/Oracle.h blib/arch/auto/DBD/Oracle/mk.pm
rm -f blib/lib/DBD/Oracle/GetInfo.pm
rm -rf Makefile Makefile.old
[mike@commando DBD-Oracle-1.14]$ perl Makefile.PL -v
Using DBI 1.38 installed in /usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI

 Configuring DBD::Oracle ...

>>>	Remember to actually *READ* the README file!
   	Especially if you have any problems.

Using Oracle in /home/orahome

WARNING: could not decode oracle version from
/home/orahome/orainst/inspdver, or /home/orahome/install/unix.rgs
or from ORACLE_HOME path /home/orahome.
Oracle version based logic in Makefile.PL may produce erroneous results.

Found header files in rdbms/public rdbms/demo.
Found /home/orahome/rdbms/demo/demo_rdbms.mk
Found /home/orahome/otrace/demo/atmoci.mk
Found /home/orahome/precomp/demo/proc/demo_proc.mk
Using /home/orahome/rdbms/demo/demo_rdbms.mk
Reading /home/orahome/rdbms/demo/demo_rdbms.mk
Reading /home/orahome/rdbms/lib/env_rdbms.mk
Read a total of 2202 lines from /home/orahome/rdbms/lib/env_rdbms.mk (including inclusions)
Read a total of 2493 lines from /home/orahome/rdbms/demo/demo_rdbms.mk (including inclusions)
Deleted SHELL definition: SHELL=/bin/sh
Deleted LIB_EXT definition: LIB_EXT=a
Deleted OBJ_EXT definition: OBJ_EXT=o
Deleted AR definition: AR=ar
Deleted AS definition: AS=as
Deleted CC definition: CC=cc
Deleted CHMOD definition: CHMOD=chmod
Deleted CPP definition: CPP=cpp
Deleted ECHO definition: ECHO=echo
Deleted LD definition: LD=ld
Deleted PERL definition: PERL=perl
Deleted CFLAGS definition: CFLAGS=$(GFLAG) $(OPTIMIZE) $(CDEBUG) $(CCFLAGS) $(PFLAGS)\
	$(SHARED_CFLAG) $(USRFLAGS)
Deleted LDFLAGS definition: LDFLAGS=-o $@ $(LDPATHFLAG)$(PRODLIBHOME) $(LDPATHFLAG)$(LIBHOME)
Deleted LDFLAGS definition: LDFLAGS=-o $@ $(LDPATHFLAG)$(PRODLIBHOME) $(LDPATHFLAG)$(LIBHOME) $(LDPATHFLAG)$(LIBHOME)stubs/
Deleted OPTIMIZE definition: OPTIMIZE=$(OPTIMIZE3)
Deleted AR definition: AR=/usr/bin/ar
Deleted AS definition: AS=/usr/bin/as
Deleted LD definition: LD=/usr/bin/ld
Deleted CPP definition: CPP=/lib/cpp
Deleted CHMOD definition: CHMOD=/bin/chmod
Deleted ASFLAGS definition: ASFLAGS=
Deleting ORA_NLS = $(ORACLE_HOME)/ocommon/nls/admin/data/
  because it is not already set in the environment
  and it can cause ORA-01019 errors.
Deleted ORA_NLS definition: ORA_NLS = $(ORACLE_HOME)/ocommon/nls/admin/data/
Deleting ORA_NLS33 = $(ORACLE_HOME)/ocommon/nls/admin/data/
  because it is not already set in the environment
  and it can cause ORA-01019 errors.
Deleted ORA_NLS33 definition: ORA_NLS33 = $(ORACLE_HOME)/ocommon/nls/admin/data/
Appending '/home/orahome/rdbms/lib/libskgxpd.a /home/orahome/rdbms/lib/libskgxpu.a /home/orahome/rdbms/lib/libskgxpt.a' to EXTRALIBS
Appending '$(LIBHOME)libskgxp9.so' to SHLIBS
Appending '/home/orahome/rdbms/lib/libskgxp9.a' to LIBS
Appending '/home/orahome/rdbms/lib/libskgxns.a /home/orahome/rdbms/lib/libskgxnd.a /home/orahome/rdbms/lib/libskgxnr.a' to EXTRALIBS
Appending '$(LIBHOME)libskgxn9.so' to SHLIBS
Appending '/home/orahome/rdbms/lib/libskgxn9.a' to LIBS
Evaluating `cat $(LIBHOME)sysliblist`
  expanded `cat /home/orahome/lib/sysliblist`
  returned '-ldl -lm -lpthread -lnsl '

Attempting to discover Oracle OCI build rules
gcc    -c -o DBD_ORA_OBJ.o DBD_ORA_OBJ.c
by executing: (make -f /home/orahome/rdbms/demo/demo_rdbms.mk build ECHODO=echo ECHO=echo GENCLNTSH='echo genclntsh' CC=echo OPTIMIZE= CCFLAGS= EXE=DBD_ORA_EXE OBJS=DBD_ORA_OBJ.o)
returned:
[echo -L/home/orahome/lib/ -L/home/orahome/rdbms/lib/ -o DBD_ORA_EXE DBD_ORA_OBJ.o -lclntsh   `cat /home/orahome/lib/sysliblist` -ldl -lm  

[-L/home/orahome/lib/ -L/home/orahome/rdbms/lib/ -o DBD_ORA_EXE DBD_ORA_OBJ.o -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm
]
reduced to:
[-L/home/orahome/lib/ -L/home/orahome/rdbms/lib/ -o DBD_ORA_EXE DBD_ORA_OBJ.o -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm
]
Oracle oci build command:
	+ -L/home/orahome/lib/ -L/home/orahome/rdbms/lib/ -o DBD_ORA_EXE DBD_ORA_OBJ.o -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm



System: perl5.008 linux stripples.devel.redhat.com 2.4.21-1.1931.2.382.entsmp #1 smp wed aug 6 17:18:52 edt 2003 i686 i686 i386 gnulinux 
Compiler:   gcc -O2 -g -pipe -march=i386 -mcpu=i686 -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm
Linker:     /usr/bin/ld
Sysliblist: -ldl -lm -lpthread -lnsl 
Oracle makefiles would have used these definitions but we override them:
  CC:       cc

  CFLAGS:   $(GFLAG) $(OPTIMIZE) $(CDEBUG) $(CCFLAGS) $(PFLAGS)\
	$(SHARED_CFLAG) $(USRFLAGS)
           [$(GFLAG) -O3 $(CDEBUG) $(CCFLAGS) -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -DLINUX -D_GNU_SOURCE -D_LARGEFILE64_SOURCE=1 -D_LARGEFILE_SOURCE=1 -DSLTS_ENABLE -DSLMXMX_ENABLE -D_REENTRANT -DNS_THREADS $(LPFLAGS) $(USRFLAGS)]

  LDFLAGS:  -o $@ $(LDPATHFLAG)$(PRODLIBHOME) $(LDPATHFLAG)$(LIBHOME) $(LDPATHFLAG)$(LIBHOME)stubs/
           [-o $@ -L/home/orahome/rdbms/lib/ -L$(LIBHOME) -L$(LIBHOME)stubs/]


Linking with OTHERLDFLAGS = -L/home/orahome/lib/ -L/home/orahome/rdbms/lib/   -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm
 [from 'build' rule]


MakeMaker (v6.03)
Checking if your kit is complete...
Looks good
  ABSTRACT_FROM => q[Oracle.pm]
  AUTHOR => q[Tim Bunce (dbi-users@perl.org)]
  DEFINE => q[ -DUTF8_SUPPORT]
  DIR => []
  EXE_FILES => [q[ora_explain]]
  INC => q[-I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/rdbms/demo -I/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI]
  NAME => q[DBD::Oracle]
  OBJECT => q[$(O_FILES)]
  PREREQ_PM => { DBI=>q[0] }
  VERSION_FROM => q[Oracle.pm]
  clean => { FILES=>q[Oracle.xsi dll.base dll.exp sqlnet.log libOracle.def ora_explain mk.pm] }
  dist => { DIST_DEFAULT=>q[clean distcheck disttest ci tardist], COMPRESS=>q[gzip -v9], PREOP=>q[$(MAKE) -f Makefile.old distdir], SUFFIX=>q[gz] }
  dynamic_lib => { OTHERLDFLAGS=>q[ -L/home/orahome/lib/ -L/home/orahome/rdbms/lib/   -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm
] }
Using PERL=/usr/bin/perl
LD_RUN_PATH=/home/orahome/lib:/home/orahome/rdbms/lib
Using DBD::Oracle 1.14.
Using DBD::Oracle 1.14.
Using DBI 1.38 installed in /usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI
Writing Makefile for DBD::Oracle

***  If you have problems...
     read all the log printed above, and the README and README.help files.
     (Of course, you have read README by now anyway, haven't you?)

[mike@commando DBD-Oracle-1.14]$ make
cp Oracle.pm blib/lib/DBD/Oracle.pm
cp Oracle.h blib/arch/auto/DBD/Oracle/Oracle.h
cp dbdimp.h blib/arch/auto/DBD/Oracle/dbdimp.h
cp oraperl.ph blib/lib/oraperl.ph
cp ocitrace.h blib/arch/auto/DBD/Oracle/ocitrace.h
cp Oraperl.pm blib/lib/Oraperl.pm
cp mk.pm blib/arch/auto/DBD/Oracle/mk.pm
cp lib/DBD/Oracle/GetInfo.pm blib/lib/DBD/Oracle/GetInfo.pm
/usr/bin/perl -p -e "s/~DRIVER~/Oracle/g" /usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI/Driver.xst > Oracle.xsi
/usr/bin/perl /usr/lib/perl5/5.8.0/ExtUtils/xsubpp  -typemap /usr/lib/perl5/5.8.0/ExtUtils/typemap  Oracle.xs > Oracle.xsc && mv Oracle.xsc Oracle.c
gcc -c  -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/rdbms/demo -I/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm -O2 -g -pipe -march=i386 -mcpu=i686   -DVERSION=\"1.14\" -DXS_VERSION=\"1.14\" -fPIC "-I/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE"  -DUTF8_SUPPORT Oracle.c
gcc -c  -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/rdbms/demo -I/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm -O2 -g -pipe -march=i386 -mcpu=i686   -DVERSION=\"1.14\" -DXS_VERSION=\"1.14\" -fPIC "-I/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE"  -DUTF8_SUPPORT dbdimp.c
gcc -c  -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/rdbms/demo -I/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm -O2 -g -pipe -march=i386 -mcpu=i686   -DVERSION=\"1.14\" -DXS_VERSION=\"1.14\" -fPIC "-I/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE"  -DUTF8_SUPPORT oci7.c
gcc -c  -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/plsql/public -I/home/orahome/network/public -I/home/orahome/rdbms/demo -I/home/orahome/rdbms/public -I/home/orahome/rdbms/demo -I/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/DBI -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm -O2 -g -pipe -march=i386 -mcpu=i686   -DVERSION=\"1.14\" -DXS_VERSION=\"1.14\" -fPIC "-I/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE"  -DUTF8_SUPPORT oci8.c
Running Mkbootstrap for DBD::Oracle ()
chmod 644 Oracle.bs
rm -f blib/arch/auto/DBD/Oracle/Oracle.so
LD_RUN_PATH="/home/orahome/lib:/home/orahome/rdbms/lib" gcc  -shared -L/usr/local/lib Oracle.o dbdimp.o oci7.o oci8.o -L/home/orahome/lib/ -L/home/orahome/rdbms/lib/   -lclntsh -ldl -lm -lpthread -lnsl -ldl -lm -o blib/arch/auto/DBD/Oracle/Oracle.so     
chmod 755 blib/arch/auto/DBD/Oracle/Oracle.so
cp Oracle.bs blib/arch/auto/DBD/Oracle/Oracle.bs
chmod 644 blib/arch/auto/DBD/Oracle/Oracle.bs
/usr/bin/perl "-Iblib/arch" "-Iblib/lib" ora_explain.PL ora_explain
Extracted ora_explain from ora_explain.PL with variable substitutions.
cp ora_explain blib/script/ora_explain
/usr/bin/perl "-MExtUtils::MY" -e "MY->fixin(shift)" blib/script/ora_explain
Manifying blib/man3/DBD::Oracle.3pm
Manifying blib/man1/ora_explain.1
Manifying blib/man3/DBD::Oraperl.3pm
[mike@commando DBD-Oracle-1.14]$ make test
PERL_DL_NONLAZY=1 /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
t/base.......                                                                             t/base.......ok 1/5                                                                             t/base.......ok 2/5                                                                             t/base.......ok 3/5                                                                             t/base.......ok 4/5                                                                             t/base.......ok 5/5                                                                             t/base.......ok
t/cursor.....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle as scott/tiger (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
skipped
        all skipped: no reason given
t/general....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at t/general.t line 20
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
skipped
        all skipped: no reason given
t/long.......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
skipped
        all skipped: no reason given
t/meta.......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle as scott/tiger (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
skipped
        all skipped: no reason given
t/ph_type....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at t/ph_type.t line 26
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
skipped
        all skipped: no reason given
t/plsql......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
skipped
        all skipped: no reason given
t/reauth.....skipped
        all skipped: no reason given
t/select.....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
skipped
        all skipped: no reason given
All tests successful, 8 tests skipped.
Files=9, Tests=5,  7 wallclock secs ( 3.82 cusr +  0.33 csys =  4.15 CPU)
PERL_DL_NONLAZY=1 /usr/bin/perl "-Iblib/lib" "-Iblib/arch" test.pl
Oraperl test application $Revision: 1.7 $


Extra tests. These are less formal and you need to read the output
to see if it looks reasonable and matches what the tests says is expected.

Oraperl emulation interface version 1.43 
DBD::Oracle 1.14 using OCI8 by Tim Bunce
DBI 1.38 by Tim Bunce

Data sources:
	


Connecting
 to '' (from command line, else uses ORACLE_SID or TWO_TASK - recommended)
 as 'scott/tiger' (via ORACLE_USERID env var or default - recommend name/passwd@dbname)
(ORACLE_SID='', TWO_TASK='')
oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at /home/mike/tmp/DBD-Oracle-1.14/blib/lib/Oraperl.pm line 104
ora_login: 12547: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach)

Generally set TWO_TASK or ORACLE_SID but not both at the same time.
Try to connect to the database using an oracle tool like sqlplus
only if that works should you suspect problems with DBD::Oracle.
Try leaving dbname value empty and set dbuser to name/passwd@dbname.

Test aborted.
make: *** [test_dynamic] Error 255
[mike@commando DBD-Oracle-1.14]$ make test TEST_VERBOSE=1
PERL_DL_NONLAZY=1 /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(1, 'blib/lib', 'blib/arch')" t/*.t
t/base.......1..5
ok 1
ok 2
ok 3
ok 4
ok 5
ok
t/cursor.....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle as scott/tiger (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
1..0
skipped
        all skipped: no reason given
t/general....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at t/general.t line 20
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
1..0
skipped
        all skipped: no reason given
t/long.......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
1..0
skipped
        all skipped: no reason given
t/meta.......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle as scott/tiger (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
1..0
skipped
        all skipped: no reason given
t/ph_type....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at t/ph_type.t line 26
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skipped.
1..0
skipped
        all skipped: no reason given
t/plsql......oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
1..0
skipped
        all skipped: no reason given
t/reauth.....ORACLE_USERID_2 not defined.
Tests skiped.
1..0
skipped
        all skipped: no reason given
t/select.....oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
Unable to connect to Oracle (ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach))
Tests skiped.
1..0
skipped
        all skipped: no reason given
All tests successful, 8 tests skipped.
Files=9, Tests=5,  7 wallclock secs ( 3.85 cusr +  0.32 csys =  4.17 CPU)
PERL_DL_NONLAZY=1 /usr/bin/perl "-Iblib/lib" "-Iblib/arch" test.pl
Oraperl test application $Revision: 1.7 $


Extra tests. These are less formal and you need to read the output
to see if it looks reasonable and matches what the tests says is expected.

Oraperl emulation interface version 1.43 
DBD::Oracle 1.14 using OCI8 by Tim Bunce
DBI 1.38 by Tim Bunce

Data sources:
	


Connecting
 to '' (from command line, else uses ORACLE_SID or TWO_TASK - recommended)
 as 'scott/tiger' (via ORACLE_USERID env var or default - recommend name/passwd@dbname)
(ORACLE_SID='', TWO_TASK='')
oracle: error while loading shared libraries: libodm9.so: cannot open shared object file: No such file or directory
DBI connect('','scott/tiger',...) failed: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach) at /home/mike/tmp/DBD-Oracle-1.14/blib/lib/Oraperl.pm line 104
ora_login: 12547: ORA-12547: TNS:lost contact (DBD ERROR: OCIServerAttach)

Generally set TWO_TASK or ORACLE_SID but not both at the same time.
Try to connect to the database using an oracle tool like sqlplus
only if that works should you suspect problems with DBD::Oracle.
Try leaving dbname value empty and set dbuser to name/passwd@dbname.

Test aborted.
make: *** [test_dynamic] Error 255
[mike@commando DBD-Oracle-1.14]$ perl _V[K[K-V
Summary of my perl5 (revision 5.0 version 8 subversion 0) configuration:
  Platform:
    osname=linux, osvers=2.4.21-1.1931.2.382.entsmp, archname=i386-linux-thread-multi
    uname='linux str'
    config_args='-des -Doptimize=-O2 -g -pipe -march=i386 -mcpu=i686 -Dmyhostname=localhost -Dperladmin=root@localhost -Dcc=gcc -Dcf_by=Red Hat, Inc. -Dinstallprefix=/usr -Dprefix=/usr -Darchname=i386-linux -Dvendorprefix=/usr -Dsiteprefix=/usr -Dotherlibdirs=/usr/lib/perl5/5.8.0 -Duseshrplib -Dusethreads -Duseithreads -Duselargefiles -Dd_dosuid -Dd_semctl_semun -Di_db -Ui_ndbm -Di_gdbm -Di_shadow -Di_syslog -Dman3ext=3pm -Duseperlio -Dinstallusrbinperl -Ubincompat5005 -Uversiononly -Dpager=/usr/bin/less -isr'
    hint=recommended, useposix=true, d_sigaction=define
    usethreads=define use5005threads=undef'
 useithreads=define usemultiplicity=
    useperlio= d_sfio=undef uselargefiles=define usesocks=undef
    use64bitint=undef use64bitall=un uselongdouble=
    usemymalloc=, bincompat5005=undef
  Compiler:
    cc='gcc', ccflags ='-D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm',
    optimize='',
    cppflags='-D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -I/usr/include/gdbm'
    ccversion='', gccversion='3.2.2 20030222 (Red Hat Linux 3.2.2-5)', gccosandvers=''
gccversion='3.2.2 200302'
    intsize=r, longsize=r, ptrsize=5, doublesize=8, byteorder=1234
    d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=12
    ivtype='long'
k', ivsize=4'
ivtype='l, nvtype='double'
o_nonbl', nvsize=, Off_t='', lseeksize=8
    alignbytes=4, prototype=define
  Linker and Libraries:
    ld='gcc'
l', ldflags =' -L/u'
    libpth=/usr/local/lib /lib /usr/lib
    libs=-lnsl -lgdbm -ldb -ldl -lm -lpthread -lc -lcrypt -lutil
    perllibs=
    libc=/lib/libc-2.3.2.so, so=so, useshrplib=true, libperl=libper
    gnulibc_version='2.3.2'
  Dynamic Linking:
    dlsrc=dl_dlopen.xs, dlext=so', d_dlsymun=undef, ccdlflags='-rdynamic -Wl,-rpath,/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE'
    cccdlflags='-fPIC'
ccdlflags='-rdynamic -Wl,-rpath,/usr/lib/perl5', lddlflags='s Unicode/Normalize XS/A'


Characteristics of this binary (from libperl): 
  Compile-time options: DEBUGGING MULTIPLICITY USE_ITHREADS USE_LARGE_FILES PERL_IMPLICIT_CONTEXT
  Locally applied patches:
  	MAINT18379
  Built under linux
  Compiled at Aug 13 2003 11:47:58
  @INC:
    /usr/lib/perl5/5.8.0/i386-linux-thread-multi
    /usr/lib/perl5/5.8.0
    /usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi
    /usr/lib/perl5/site_perl/5.8.0
    /usr/lib/perl5/site_perl
    /usr/lib/perl5/vendor_perl/5.8.0/i386-linux-thread-multi
    /usr/lib/perl5/vendor_perl/5.8.0
    /usr/lib/perl5/vendor_perl
    /usr/lib/perl5/5.8.0/i386-linux-thread-multi
    /usr/lib/perl5/5.8.0
    .
[mike@commando DBD-Oracle-1.14]$ ^D
Script done on Fri 28 Nov 2003 09:16:43 AM PST
------------ end log -----------------------------------


