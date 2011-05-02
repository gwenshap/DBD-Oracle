From dbi-users-return-22430-Tim.Bunce=pobox.com@perl.org  Tue Mar 23 17:00:25 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i2NGvAxX021862
	for <timbo@localhost>; Tue, 23 Mar 2004 17:00:23 GMT
	(envelope-from dbi-users-return-22430-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 23 Mar 2004 17:00:23 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1B5oND-0000Ba-LH;
	Tue, 23 Mar 2004 16:03:27 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1B5oND-0000Ba-LH
	for pobox@dbi.demon.co.uk; Tue, 23 Mar 2004 16:03:27 +0000
Received: from [208.210.124.70] (helo=majesty.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1B5oNC-00001d-92
	for pobox@dbi.demon.co.uk; Tue, 23 Mar 2004 16:03:26 +0000
Received: from majesty.pobox.com (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 18033954B4
	for <pobox@dbi.demon.co.uk>; Tue, 23 Mar 2004 11:03:24 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by majesty.pobox.com (Postfix) with ESMTP id 3577D954BE
	for <Tim.Bunce@pobox.com>; Tue, 23 Mar 2004 11:03:21 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by majesty.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Tue, 23 Mar 2004 11:02:41 -0500 (EST)
Received: (qmail 6527 invoked by uid 1005); 23 Mar 2004 16:02:21 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 6510 invoked by uid 76); 23 Mar 2004 16:02:20 -0000
Received: from x1.develooper.com (HELO x1.develooper.com) (63.251.223.170)
  by onion.perl.org (qpsmtpd/0.27.1) with SMTP; Tue, 23 Mar 2004 08:02:20 -0800
Received: (qmail 1985 invoked by uid 225); 23 Mar 2004 16:02:15 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 1893 invoked by alias); 23 Mar 2004 16:02:00 -0000
X-Spam-Status: No, hits=0.0 required=7.0
	tests=
X-Spam-Check-By: la.mx.develooper.com
Received: from Unknown (HELO dundee.fpcc.net) (204.144.241.120)
  by la.mx.develooper.com (qpsmtpd/0.27.1) with ESMTP; Tue, 23 Mar 2004 08:01:44 -0800
Received: from aberdeen.fpcc.net (aberdeen.fpcc.net [204.144.241.125])
	by dundee.fpcc.net (8.11.6/8.11.6) with ESMTP id i2NG1f111241;
	Tue, 23 Mar 2004 09:01:41 -0700
Received: from aberdeen.fpcc.net (localhost.localdomain [127.0.0.1])
	by aberdeen.fpcc.net (8.12.8/8.12.8) with ESMTP id i2NFrNOv024637;
	Tue, 23 Mar 2004 08:53:23 -0700
Received: (from laubster@localhost)
	by aberdeen.fpcc.net (8.12.8/8.12.8/Submit) id i2NFrMOx024635;
	Tue, 23 Mar 2004 08:53:22 -0700
X-Authentication-Warning: aberdeen.fpcc.net: laubster set sender to dbiusers@laubster.org using -f
Date: Tue, 23 Mar 2004 08:53:22 -0700
From: "J.D. Laub" <dbiusers@laubster.org>
To: dbi-users@perl.org
Cc: lbaxter@fleetcc.com
Subject: SUCCESS: DBD::Oracle 1.15 on HP-UX 11.11
Message-ID: <20040323155322.GA24576@aberdeen.fpcc.net>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.4.1i
Organization: The Psychiatric Ward of Terrors
X-Virus-Checked: Checked
Status: RO
Content-Length: 9105
Lines: 206

I've just had success building DBD::Oracle 1.15 on HP-UX 11.11
(against both oracle 8.1.7 & oracle 9.2.0) & thought I'd share my
experience.

Disclaimer: these instructions relate to our environment.  It may be
that our sysadmins/dbas chose to configure/install things a certain
way (i.e., our install of $ORACLE_HOME/bin/sqlplus was *chosen*
to be 1.1/32), and/or that we're running old versions of software
(i.e., perhaps later releases of gcc don't ignore -mpa-risc-1-1).
In fact, there are probably some mistruths in here; rest assured
they're not intentional. :-)

I'm unsure how (if?) I should go about getting this information into
the DBD::Oracle README.hpux.  Lincoln, please contact me with any
thoughts you have.


###  The summary  ################################

Use the ansic compiler (~US$800/cpu).

Shell variables I used:
    PATH=/bin:$PATH # use 32bit ar & nm since using a 32bit cc
    PERLDEST=/opt/perl_ora8 # or "perl_ora9" for an ora9 build
    PATH=$PERLDEST/bin:$PATH # for build of DBI, pick up new perl
    export LDLOADLIBS='+b : +s' # handy for ORACLE_SID connections to ora7
    unset PERLLIB # important to avoid outdated cruft
    export ORACLE_USERID=scott/tiger # insecure - consider using "/"
    ORACLE_SID=orcl
    ORAENV_ASK=NO
    . oraenv # sets LD_LIBRARY_PATH and SHLIB_PATH

For ora8:
    sh ./Configure -d -e -Dprefix=$PERLDEST \
        -A prepend:libswanted='cl pthread ' \
        -A prepend:ccflags='+z +DAportable ' \
        -A prepend:ldflags='+z +DAportable '

For ora9:
    sh ./Configure -d -e -Dprefix=$PERLDEST \
        -A prepend:libswanted='cl pthread ' \
        -A prepend:ccflags='+z +DA2.0W ' \
        -A prepend:ldflags='+z +DA2.0W ' \
        -Dlibpth='/usr/lib/pa20_64 /usr/local/pa20_64/lib'

After you use the above to install perl, DBI & DBD::Oracle will
build in the normal fashion.


###  General Notes ################################

* During "make test", I received 1 failure (on
lib/ExtUtils/t/Constant) for ora8, and 3 failures (on
lib/ExtUtils/t/Constant, lib/ExtUtils/t/recurs, and t/op/write) for
ora9.  Nevertheless, things seem mostly OK.

* These are the various combinations possible for a given compiled
file on HP-UX 11.11 (the quoted description is what gets kicked out
by the "file" command):

    PA-RISC1.1/32bit ("PA-RISC1.1 relocatable object")
        (I'll call this 1.1/32)
    PA-RISC2.0/32bit ("PA-RISC2.0 relocatable object")
        (I'll call this 2.0/32)
    PA-RISC2.0/64bit ("ELF 64-bit MSB relocatable, PA-RISC 2.0 (LP64)")
        (I'll call this 2.0/64)

* "perl -v" lies about the RISC level:
$ file ./perl
./perl:    PA-RISC1.1 shared executable dynamically linked -not stripped
$ ./perl -v | grep RISC
This is perl, v5.8.3 built for PA-RISC2.0

* If you'll be linking against 2.0/64 libraries, you'll have to
build all your object modules that way.  I've not yet found a way
to link 32bit executables to 64bit libraries (and vice versa).  Run
the "file" command on your Oracle libraries to find out which path
you'll have to take.

* Two environment variables control where libraries are
searched. LD_LIBRARY_PATH and SHLIB_PATH (in that order) are
used for 64bit executables, while SHLIB_PATH is used for 32bit
executables.

* I tried attempts using aCC as well as the default (free) cc that
comes with hpux; both avenues were too problematic to continue
pursuing.

* The format of compiled objects is specified by compiler options.
According to the ansic compiler docs, the options are "+DAportable"
(for 1.1/32), "+DA2.0" (for 2.0/32), and "+DA2.0W" (for 2.0/64).
For gcc, the corresponding switches are -mpa-risc-1-1 (for 1.1/32)
and -mpa-risc-2-0 (for 2.0/64), but I've found that -mpa-risc-1-1
is ineffective.  (According to the "file" command, you *always* get
2.0/64.)

* Our gcc displays the behavior described at
http://sources.redhat.com/ml/binutils/2002-10/msg00586.html and
http://aspn.activestate.com/ASPN/Mail/Message/perl5-porters/1641238
, so is therefore unusable anytime '-lcl' is to be specified.
Unfortunately, that library is required for DBD::Oracle builds.
(The workaround of adding the 3 declarations does seem to work,
but littering those throughout perl's Configure, main.c, etc.
seems a big task.)  Attempts to get gcc to use the hp ld instead
of the gnu ld (by specifying -mno-gnu-ld and -fno-gnu-linker) were
unsuccessful.  The first html link shown above indicates you have
to rebuild gcc to use the hp linker, and that was not an incredibly
desirable path to pursue.

* Our default PATH was set to put /usr/local/pa20_64/bin ahead of
/bin.  This caused problems because (I think) the 64bit versions
of either ar (the archiver) or nm (the symbol lister) do not play
well with /bin/cc (the 32bit compiler).  The tweak to put /bin at
the head of PATH, so we get the 32bit versions, takes care of the
problem.

* I ran into an intermittent quirk during the build of perl in which
typing "make" (just after the Configure) did nothing.  It turns out
that only dependencies were being written to "makefile", and that
removing "makefile" (so it could be automatically rebuilt) solved
the problem.

* Most of my research on finding the right compiler/linker switches
was done with a "hello world" C program, trying the various
compilers and options, and trying to link it with the oracle
libraries.  This proved to be a good choice, as trying to test
compilers/switches against the perl source distribution would have
proved quite difficult.


###  DBD::Oracle specific  ################################

* ora8 delivers its libraries in 2 formats: 1.1/32 (under
$ORACLE_HOME/lib) and 2.0/64 (under $ORACLE_HOME/lib64). ora7
delivers only 1.1/32, while ora9 delivers only 2.0/64.  It may seem
a bit inconsistent considering the ora8 setup, but ora9 libraries
are found under $ORACLE_HOME/lib and not $ORACLE_HOME/lib64.

* Under ora8, oraenv incorrectly sets LD_LIBRARY_PATH to include
$ORACLE_HOME/lib instead of $ORACLE_HOME/lib64, so you've got to
make an override in oraenv_local if you want to use 2.0/64.  It
doesn't harm anything, but oraenv unnecessarily sets LD_LIBRARY_PATH
for ora7 (a 64bit environment variable for a 32bit application).

* If you use shared libraries AND you'll be upgrading Oracle, you
should expect you'll need to rebuild DBD::Oracle unless you'll keep
the old Oracle libraries available.

* If you're building against ora8, the setting of LDLOADLIBS
is recommended so that when oraenv set SHLIB_PATH to the
$ORACLE_HOME/lib for ora7, the code will still find the ora8
libraries.

* We expect to need local (ORACLE_SID) connections for ora8 &
ora9.  We could have gone with a single 2.0/64 perl coupled with
2 DBD::Oracle installs and PERLLIB twiddling in oraenv_local to
get to the right one.  Instead, we chose to do 2 perl installs
(/opt/perl_ora8 and /opt/perl_ora9) because we can also connect
locally to ora7 by using the 1.1/32 ora8 version, something that
isn't possible with a 2.0/64 version.  Also, we've some older 1.1/32
machines into which we'd like to plop a tarball of the perl stuff,
so a 1.1/32 executable was desirable.

* Some tests I ran were hinting that with 2.0/64, specifying "+b :"
on the build of DBD::Oracle correctly configured Oracle.sl as far as
the chatr program is concerned, but it seemed that LD_LIBRARY_PATH
*always* needed to be set correctly.  (I.e., the embedded path in
the library seemed to be ignored.)  I didn't pursue researching this
since there's no way to get the ora9 compiled code to connect to
ora8, meaning LD_LIBRARY_PATH had to be set correctly anyway.

Testing local (ORACLE_SID) connections:
builds against 1.1/32 ora8 can    connect to ora7
builds against 1.1/32 ora8 cannot connect to ora9: "ERROR OCIEnvInit"
builds against 2.0/64 ora8 cannot connect to ora9: "ERROR OCIEnvInit"
builds against 2.0/64 ora9 cannot connect to ora8 or ora7: "UNKNOWN
    OCI STATUS 1804) OCIInitialize. Check ORACLE_HOME and NLS
    settings etc."

Testing remote (sqlnet) connections:
builds against 1.1/32 ora8 can    connect to ora7
builds against 1.1/32 ora8 can    connect to ora9
builds against 2.0/64 ora9 can    connect to ora8
builds against 2.0/64 ora9 cannot connect to ora7: "OCI-21500: internal
    error code"


###  Versions  ################################

perl: 5.8.3
dbi: 1.41
dbd-oracle: 1.15
$ strings /bin/cc | grep Compiler
HP92453-01 B.11.11.08 HP C Compiler
$ strings /bin/ld | grep linker
$Revision: 92453-07 linker linker crt0.o B.11.16 000601 $
@(#)92453-07 linker command s800.sgs ld PA64 B.11.18 REL 000922
$ gcc -v
Reading specs from /usr/local/pa20_64/lib/gcc-lib/hppa64-hp-hpux11.11/3.3.1/specs
Configured with: ../src/configure --enable-languages=c,c++ --prefix=/usr/local/pa20_64 --with-local-prefix=/usr/local/pa20_64 --with-gnu-as --with-as=/usr/local/pa20_64/bin/as --with-gnu-ld --with-ld=/usr/local/pa20_64/bin/ld --disable-shared --disable-nls --host=hppa64-hp-hpux11.11
Thread model: single
gcc version 3.3.1

-- 
J.D. Laub (Laubster) |"Your leg's too long / Your skull's too strong /
dbiusers@laubster.org| Suppose your nose is wrong." - Renaldo & the Loaf

