From cary.millsap@hotsos.com  Thu Sep 12 23:38:20 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8CMbgC02618
	for <timbo@localhost>; Thu, 12 Sep 2002 23:38:03 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 12 Sep 2002 23:38:03 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031869308:20:16258:30; Thu, 12 Sep 2002 22:21:48 GMT
Received: from cali-3.pobox.com ([64.71.166.116]) by punt-2.mail.demon.net
           id aa2108888; 12 Sep 2002 22:21 GMT
Received: from cali-3.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-3.pobox.com (Postfix) with ESMTP id A32132F05C9
	for <Tim.Bunce@data-plan.com>; Thu, 12 Sep 2002 18:21:34 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by cali-3.pobox.com (Postfix) with ESMTP id D71F62F056D
	for <tim.bunce@pobox.com>; Thu, 12 Sep 2002 18:21:31 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8CMLQn17849;
	Thu, 12 Sep 2002 17:21:26 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: <tim.bunce@pobox.com>
Subject: 
Date: Thu, 12 Sep 2002 17:21:17 -0500
Message-ID: <016901c25aaa$ba287930$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: multipart/mixed;
	boundary="----=_NextPart_000_016A_01C25A80.D1527130"
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 64884
Lines: 2025

This is a multi-part message in MIME format.

------=_NextPart_000_016A_01C25A80.D1527130
Content-Type: multipart/alternative;
	boundary="----=_NextPart_001_016B_01C25A80.D1557E70"


------=_NextPart_001_016B_01C25A80.D1557E70
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

Tim,

 

How are you doing? I hope you've had a good two years since I saw you on
the Oracle Geek Cruise event.

 

I've been working on a project this year to construct a book about
optimizing Oracle response time. In my research, I've discovered
something about the DBI that I didn't expect: it executes two Oracle
parse calls for every one that I would expect an efficient DBI layer to
make. I've included my Perl source (below), the Oracle level-12 trace
data that shows the sequence of calls it's receiving from the Perl
application (below), a level-9 DBI trace from the application
(attached), and our version information (below).

 

The reason I'm bringing this to your attention in this way is that I'm
relying pretty heavily upon Perl for performance measurement tools,
examples, and simulators in the text. I love the language and I want for
the book to be an encouragement for more people to use Perl. However,
this extra-parse behavior is one of the things that the book highlights
as an important scalability barrier (some other tools do it too,
unfortunately). Of course, this is a speed bump on the road to my goal
of helping to promote Perl.

 

I was hoping that by showing you this specific data, you could make the
problem go away.

 

Cary Millsap
Hotsos Enterprises, Ltd.
http://www.hotsos.com

Upcoming events:
- Hotsos Clinic <http://www.hotsos.com/training/clinic> , Oct 1-3 San
Francisco, Oct 15-17 Dallas, Dec 9-11 Honolulu
- 2003 Hotsos Symposium <http://www.hotsos.com/events/symposium>  on
OracleR System Performance, Feb 9-12 Dallas
- Next event: Miracle Database Forum <http://www.miracleas.dk> , Sep
20-22 Middlefart Denmark

Listing [listing.sqltrace.pl]: a simple application that executes a
database query

#!/usr/bin/perl

 

 

# $Header: /home/cvs/cvm-book1/sqltrace/ex1.pl,v 1.2 2002/09/12 21:10:25
cvm Exp $

# Cary Millsap (cary.millsap@hotsos.com)

 

 

use strict;

use warnings;

use DBI;

use DBD::Oracle;

use Getopt::Long;

use Term::ReadKey;

 

 

my $sth;                    # Oracle statement handle

my $hostname = "";

my $username = "/";

my $password = "";

my $logfile  = "ex1.log";

my %attr = (

    RaiseError => 1,

    AutoCommit => 0,

);

my %opt = (

    pause   => 0,

);

 

 

# Get command line options and arguments.

GetOptions(

    "pause" => \$opt{pause},

);

my $key = 37;               # default query value

$key = $ARGV[0] if $ARGV[0];

 

 

# Connect to Oracle.

my $dbh = DBI->connect("dbi:Oracle:$hostname", $username, $password,
\%attr);

$dbh->trace(9, $logfile);

 

 

# Activate tracing.

$sth = $dbh->prepare(q(alter session set events '10046 trace name
context forever, level 12'));

$sth->execute;

 

 

# Allow the user to find the Oracle session and activate OS diagnostic

# tools like strace(1) or lsof(8).

if ($opt{pause}) {

    print "Press any key to continue...";

    1 while not defined (my $k = ReadKey(-1));

    print "\n";

}

 

 

# Execute the query to trace.

$sth = $dbh->prepare(q(select key, fkey, value from t where key=?));

$sth->execute($key);

 

 

# Print output header.

my @cdefs = qw(%8d %8d %32s);   # column definitions

my @hdefs = qw(Key Fkey Value); # column headings

my $bformat = join("  ", @cdefs) . "\n";

my $hformat; ($hformat = $bformat) =~ s/%(\d*)\S+/%$1s/g;

printf $hformat, @hdefs;

printf $hformat, do { my @h; push @h, "-" x (/(\d+)/?$1:10) for @cdefs;
@h };

 

 

# Print query results.

for my $row (@{$sth->fetchall_arrayref}) {

    printf $bformat, @$row;

}

 

 

# Allow the user to do final OS diagnostic stuff.

if ($opt{pause}) {

    print "Press any key to continue...";

    1 while not defined (my $k = ReadKey(-1));

    print "\n";

}

 

 

# Disconnect from Oracle.

$dbh->disconnect;

 

 

Listing [listing:sqltrace.trc]: raw SQL trace output for an execution of
our program

/usr/local/oracle/admin/V816/udump/ora_17349.trc

Oracle8i Enterprise Edition Release 8.1.6.1.0 - Production

With the Partitioning option

JServer Release 8.1.6.0.0 - Production

ORACLE_HOME = /usr/local/oracle/product/8.1.6

System name:        Linux

Node name:  www.hotsos.com

Release:    2.2.16-22enterprise

Version:    #1 SMP Tue Aug 22 16:29:32 EDT 2000

Machine:    i686

Instance name: V816

Redo thread mounted by this instance: 1

Oracle process number: 8

Unix process pid: 17349, image: oracle@www.hotsos.com (TNS V1-V3)

 

*** SESSION ID:(7.9) 2002-09-12 16:14:01.582

=====================

PARSING IN CURSOR #1 len=69 dep=0 uid=12 oct=42 lid=12 tim=107309054
hv=1509700594 ad='54af5e14'

alter session set events '10046 trace name context forever, level 12'

END OF STMT

EXEC #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107309054

WAIT #1: nam='SQL*Net message to client' ela= 0 p1=1650815232 p2=1 p3=0

*** 2002-09-12 16:14:31.226

WAIT #1: nam='SQL*Net message from client' ela= 2964 p1=1650815232 p2=1
p3=0

=====================

PARSING IN CURSOR #2 len=44 dep=0 uid=12 oct=3 lid=12 tim=107312018
hv=1997601641 ad='54af1384'

select key, fkey, value from t where key=:p1

END OF STMT

PARSE #2:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312018

WAIT #2: nam='SQL*Net message to client' ela= 0 p1=1650815232 p2=1 p3=0

WAIT #2: nam='SQL*Net message from client' ela= 0 p1=1650815232 p2=1
p3=0

=====================

PARSING IN CURSOR #1 len=44 dep=0 uid=12 oct=3 lid=12 tim=107312019
hv=1997601641 ad='54af1384'

select key, fkey, value from t where key=:p1

END OF STMT

PARSE #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312019

BINDS #1:

 bind 0: dty=1 mxl=32(04) mal=00 scl=00 pre=00 oacflg=25 oacfl2=10
size=32 offset=0

   bfp=0940e7f0 bln=32 avl=04 flg=05

   value="8542"

EXEC #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312019

WAIT #1: nam='SQL*Net message to client' ela= 0 p1=1650815232 p2=1 p3=0

WAIT #1: nam='file open' ela= 0 p1=0 p2=0 p3=0

WAIT #1: nam='db file sequential read' ela= 0 p1=1 p2=6671 p3=1

WAIT #1: nam='db file sequential read' ela= 0 p1=1 p2=6678 p3=1

FETCH #1:c=0,e=0,p=2,cr=3,cu=0,mis=0,r=1,dep=0,og=3,tim=107312019

*** 2002-09-12 16:14:56.200

WAIT #1: nam='SQL*Net message from client' ela= 2496 p1=1650815232 p2=1
p3=0

XCTEND rlbk=0, rd_only=1

STAT #1 id=1 cnt=1 pid=0 pos=0 obj=5156 op='TABLE ACCESS BY INDEX ROWID
T '

STAT #1 id=2 cnt=2 pid=1 pos=1 obj=5157 op='INDEX UNIQUE SCAN '

 

 

$ perl -V

Summary of my perl5 (revision 5.0 version 6 subversion 0) configuration:

  Platform:

    osname=linux, osvers=2.2.5-22smp, archname=i386-linux

    uname='linux porky.devel.redhat.com 2.2.5-22smp #1 smp wed jun 2
09:11:51 edt 1999 i686 unknown '

    config_args='-des -Doptimize=-O2 -march=i386 -mcpu=i686 -Dcc=gcc
-Dcccdlflags=-fPIC -Dinstallprefix=/usr -Dprefix=/usr
-Darchname=i386-linux -Dd_dosuid -Dd_semctl_semun -Di_db -Di_ndbm
-Di_gdbm -Di_shadow -Di_syslog -Dman3ext=3pm -Uuselargefiles'

    hint=recommended, useposix=true, d_sigaction=define

    usethreads=undef use5005threads=undef useithreads=undef
usemultiplicity=undef

    useperlio=undef d_sfio=undef uselargefiles=undef 

    use64bitint=undef use64bitall=undef uselongdouble=undef
usesocks=undef

  Compiler:

    cc='gcc', optimize='-O2 -march=i386 -mcpu=i686', gccversion=2.96
20000731 (experimental)

    cppflags='-fno-strict-aliasing'

    ccflags ='-fno-strict-aliasing'

    stdchar='char', d_stdstdio=define, usevfork=false

    intsize=4, longsize=4, ptrsize=4, doublesize=8

    d_longlong=define, longlongsize=8, d_longdbl=define, longdblsize=12

    ivtype='long', ivsize=4, nvtype='double', nvsize=8, Off_t='off_t',
lseeksize=4

    alignbytes=4, usemymalloc=n, prototype=define

  Linker and Libraries:

    ld='gcc', ldflags =' -L/usr/local/lib'

    libpth=/usr/local/lib /lib /usr/lib

    libs=-lnsl -ldl -lm -lc -lcrypt

    libc=/lib/libc-2.1.92.so, so=so, useshrplib=false, libperl=libperl.a

  Dynamic Linking:

    dlsrc=dl_dlopen.xs, dlext=so, d_dlsymun=undef, ccdlflags='-rdynamic'

    cccdlflags='-fPIC', lddlflags='-shared -L/usr/local/lib'

 

 

Characteristics of this binary (from libperl): 

  Compile-time options:

  Built under linux

  Compiled at Aug  7 2000 10:59:51

  @INC:

    /usr/lib/perl5/5.6.0/i386-linux

    /usr/lib/perl5/5.6.0

    /usr/lib/perl5/site_perl/5.6.0/i386-linux

    /usr/lib/perl5/site_perl/5.6.0

    /usr/lib/perl5/site_perl

    .

 

 

Other site information

- Redhat Linux 7.0

- Oracle 8.1.6.1.0

- DBD-Oracle 1.12

- DBI 1.30

 


------=_NextPart_001_016B_01C25A80.D1557E70
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>

<head>
<META HTTP-EQUIV=3D"Content-Type" CONTENT=3D"text/html; =
charset=3Dus-ascii">


<meta name=3DGenerator content=3D"Microsoft Word 10 (filtered)">

<style>
<!--
 /* Font Definitions */
 @font-face
	{font-family:Times;
	panose-1:2 2 6 3 5 4 5 2 3 4;}
 /* Style Definitions */
 p.MsoNormal, li.MsoNormal, div.MsoNormal
	{margin:0in;
	margin-bottom:.0001pt;
	font-size:12.0pt;
	font-family:"Times New Roman";}
a:link, span.MsoHyperlink
	{color:blue;
	text-decoration:underline;}
a:visited, span.MsoHyperlinkFollowed
	{color:purple;
	text-decoration:underline;}
p
	{margin-right:0in;
	margin-left:0in;
	font-size:12.0pt;
	font-family:"Times New Roman";}
span.EmailStyle17
	{font-family:Arial;
	color:windowtext;}
p.Code, li.Code, div.Code
	{margin-top:0in;
	margin-right:-67.7pt;
	margin-bottom:0in;
	margin-left:.25in;
	margin-bottom:.0001pt;
	border:none;
	padding:0in;
	font-size:9.0pt;
	font-family:"Courier New";
	color:green;
	letter-spacing:-.5pt;}
p.ExampleTitle, li.ExampleTitle, div.ExampleTitle
	{margin-top:4.0pt;
	margin-right:-.2in;
	margin-bottom:4.0pt;
	margin-left:.25in;
	text-align:center;
	line-height:12.0pt;
	border:none;
	padding:0in;
	font-size:10.0pt;
	font-family:Times;
	color:green;
	font-style:italic;}
span.CodeChar
	{font-family:"Courier New";
	color:green;
	letter-spacing:-.5pt;}
@page Section1
	{size:8.5in 11.0in;
	margin:1.0in 1.25in 1.0in 1.25in;}
div.Section1
	{page:Section1;}
-->
</style>

</head>

<body lang=3DEN-US link=3Dblue vlink=3Dpurple>

<div class=3DSection1>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
 font-family:Arial'>Tim</span></font><font size=3D2 face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'>,</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>How are you doing? I hope you&#8217;ve had a good two =
years
since I saw you on the Oracle Geek Cruise event.</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>I&#8217;ve been working on a project this year to =
construct
a book about optimizing Oracle response time. In my research, I&#8217;ve
discovered something about the DBI that I didn&#8217;t expect: it =
executes two
Oracle parse calls for every one that I would expect an efficient DBI =
layer to
make. I&#8217;ve included my Perl source (below), the Oracle level-12 =
trace
data that shows the sequence of calls it&#8217;s receiving from the Perl =
application
(below), a level-9 DBI trace from the application (attached), and our =
version information
(below).</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>The reason I&#8217;m bringing this to your attention =
in this
way is that I&#8217;m relying pretty heavily upon Perl for performance
measurement tools, examples, and simulators in the text. I love the =
language
and I want for the book to be an encouragement for more people to use =
Perl.
However, this extra-parse behavior is one of the things that the book =
highlights
as an important scalability barrier (some other tools do it too, =
unfortunately).
Of course, this is a speed bump on the road to my goal of helping to =
promote Perl.</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>I was hoping that by showing you this specific data, =
you
could make the problem go away.</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p><b><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial;
   font-weight:bold'>Cary</span></font></b><b><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial;font-weight:bold'> =
Millsap</span></font></b><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'><br>
Hotsos Enterprises, Ltd.<br>
<a href=3D"http://www.hotsos.com">http://www.hotsos.com</a><br>
<br>
Upcoming events:<br>
- <a href=3D"http://www.hotsos.com/training/clinic">Hotsos Clinic</a>, =
Oct
1&#8211;3 </span></font><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
  font-family:Arial'>San Francisco</span></font><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'>, Oct 15&#8211;17 =
</span></font><font
   size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>Dallas</span></font><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>, Dec
9&#8211;11 </span></font><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
  font-family:Arial'>Honolulu</span></font><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'><br>
- <a href=3D"http://www.hotsos.com/events/symposium">2003 Hotsos =
Symposium</a> on
Oracle<sup>&reg;</sup> System Performance, Feb 9&#8211;12 =
</span></font><font
   size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>Dallas</span></font><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'><br>
- Next event: <a href=3D"http://www.miracleas.dk">Miracle Database =
Forum</a>, Sep
20&#8211;22 Middlefart </span></font><font size=3D2 face=3DArial><span
  style=3D'font-size:10.0pt;font-family:Arial'>Denmark</span></font></p>

<div style=3D'border:none;border-left:solid windowtext 1.0pt;padding:0in =
0in 0in 2.0pt;
margin-left:.25in;margin-right:-.2in'>

<p class=3DExampleTitle =
style=3D'margin-right:0in;margin-bottom:4.0pt;margin-left:
0in'><i><font size=3D2 color=3Dgreen face=3DTimes><span =
style=3D'font-size:10.0pt'>Listing&nbsp;<span
style=3D'background:lime'>[listing.sqltrace.pl]</span>: a simple =
application that
executes a database query</span></font></i></p>

</div>

<div style=3D'border:none;border-left:solid windowtext 1.0pt;padding:0in =
0in 0in 2.0pt;
margin-left:.25in;margin-right:-67.7pt'>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>#!/usr/bin/perl</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
$Header:
/home/cvs/cvm-book1/sqltrace/ex1.pl,v 1.2 2002/09/12 =
</span></font>21:10:25 cvm Exp $</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Cary Millsap (cary.millsap@hotsos.com)</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
strict;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
warnings;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
DBI;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
DBD::Oracle;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
Getopt::Long;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>use =
Term::ReadKey;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my
$sth;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&n=
bsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
# Oracle statement handle</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$hostname =3D
&quot;&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$username =3D
&quot;/&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$password =3D
&quot;&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$logfile&nbsp;
=3D &quot;ex1.log&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
%attr =3D (</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
RaiseError =3D&gt; 1,</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
AutoCommit =3D&gt; 0,</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
%opt =3D (</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
pause&nbsp;&nbsp; =3D&gt; 0,</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># Get =
command line
options and arguments.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>GetOptions(</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
&quot;pause&quot; =3D&gt; \$opt{pause},</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$key =3D
37;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbs=
p;&nbsp;
&nbsp;# default query value</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>$key =
=3D $ARGV[0] if
$ARGV[0];</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Connect to
Oracle.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$dbh =3D
DBI-&gt;connect(&quot;dbi:Oracle:$hostname&quot;, $username, $password,
\%attr);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>$dbh-&gt;trace(9,
$logfile);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Activate
tracing.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>$sth =
=3D
$dbh-&gt;prepare(q(alter session set events '10046 trace name context =
forever,
level 12'));</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>$sth-&gt;execute;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Allow the user
to find the Oracle session and activate OS diagnostic</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
tools like
strace(1) or lsof(8).</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>if =
($opt{pause}) {</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
print &quot;Press any key to continue...&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
1 while not defined (my $k =3D ReadKey(-1));</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
print &quot;\n&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>}</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Execute the
query to trace.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>$sth =
=3D
$dbh-&gt;prepare(q(select key, fkey, value from t where =
key=3D?));</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>$sth-&gt;execute($key);</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Print output
header.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
@cdefs =3D qw(%8d
%8d %32s);&nbsp;&nbsp; # column definitions</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
@hdefs =3D qw(Key
Fkey Value); # column headings</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$bformat =3D
join(&quot;&nbsp; &quot;, @cdefs) . &quot;\n&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>my =
$hformat;
($hformat =3D $bformat) =3D~ s/%(\d*)\S+/%$1s/g;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>printf $hformat,
@hdefs;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>printf $hformat,
do { my @h; push @h, &quot;-&quot; x (/(\d+)/?$</span></font>1:10) for =
@cdefs; @h };</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Print query
results.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>for =
my $row
(@{$sth-&gt;fetchall_arrayref}) {</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
printf $bformat, @$row;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>}</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Allow the user
to do final OS diagnostic stuff.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>if =
($opt{pause}) {</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
print &quot;Press any key to continue...&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
1 while not defined (my $k =3D ReadKey(-1));</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;&nbsp;
print &quot;\n&quot;;</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>}</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'># =
Disconnect from
Oracle.</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>$dbh-&gt;disconnect;</span></font></p>

</div>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<div style=3D'border:none;border-left:solid windowtext 1.0pt;padding:0in =
0in 0in 2.0pt;
margin-left:.25in;margin-right:-.2in'>

<p class=3DExampleTitle =
style=3D'margin-right:0in;margin-bottom:4.0pt;margin-left:
0in'><i><font size=3D2 color=3Dgreen face=3DTimes><span =
style=3D'font-size:10.0pt'>Listing&nbsp;<span
style=3D'background:lime'>[listing:sqltrace.trc]</span>: raw SQL trace =
output for
an execution of our program</span></font></i></p>

</div>

<div style=3D'border:none;border-left:solid windowtext 1.0pt;padding:0in =
0in 0in 2.0pt;
margin-left:.25in;margin-right:-67.7pt'>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DPT-BR =
style=3D'font-size:9.0pt'>/usr/local/oracle/admin/V816/udump/ora_17349.tr=
c</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>Oracle8i </span></font>Enterprise
Edition Release 8.1.6.1.0 - Production</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>With =
the
Partitioning option</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>JServer Release
8.1.6.0.0 - Production</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>ORACLE_HOME =3D
/usr/local/oracle/product/8.1.6</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DDA =
style=3D'font-size:9.0pt'>System
name:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Linux</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DDA =
style=3D'font-size:9.0pt'>Node name:&nbsp; =
www.hotsos.com</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DDA =
style=3D'font-size:9.0pt'>Release:&nbsp;&nbsp;&nbsp; =
2.2.16-22enterprise</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DDA =
style=3D'font-size:9.0pt'>Version:&nbsp;&nbsp;&nbsp; #1
SMP Tue Aug 22 16:29:32 EDT 2000</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>Machine:&nbsp;&nbsp;&nbsp; =
i686</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>Instance name:
V816</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>Redo =
thread
mounted by this instance: 1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>Oracle process
number: 8</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>Unix =
process pid:
17349, image: oracle@www.hotsos.com (TNS V1-V3)</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New">&nbsp;</font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>*** =
SESSION
ID:(7.9) 2002-09-12 16:14:01.582</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=
=3D=3D=3D=3D=3D</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>PARSING IN CURSOR
#1 len=3D69 dep=3D0 uid=3D12 oct=3D42 lid=3D12 =
</span></font>tim=3D107309054 hv=3D1509700594
ad=3D'54af5e14'</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>alter =
session set
events '10046 trace name context forever, level 12'</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>END =
OF STMT</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>EXEC
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
309054</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1:
nam=3D'SQL*Net message to client' ela=3D 0 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>*** =
2002-09-12
16:14:31.226</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1:
nam=3D'SQL*Net message from client' ela=3D 2964 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=
=3D=3D=3D=3D=3D</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>PARSING IN CURSOR
#2 len=3D44 dep=3D0 uid=3D12 oct=3D3 lid=3D12 =
</span></font>tim=3D107312018 hv=3D1997601641
ad=3D'54af1384'</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>select key, fkey,
value from t where key=3D:p1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>END =
OF STMT</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>PARSE
#2:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312018</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#2:
nam=3D'SQL*Net message to client' ela=3D 0 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#2:
nam=3D'SQL*Net message from client' ela=3D 0 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=
=3D=3D=3D=3D=3D</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>PARSING IN CURSOR
#1 len=3D44 dep=3D0 uid=3D12 oct=3D3 lid=3D12 =
</span></font>tim=3D107312019 hv=3D1997601641
ad=3D'54af1384'</p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>select key, fkey,
value from t where key=3D:p1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>END =
OF STMT</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>PARSE
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>BINDS =
#1:</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;bind 0:
dty=3D1 mxl=3D32(04) mal=3D00 scl=3D00 pre=3D00 oacflg=3D25 oacfl2=3D10 =
size=3D32 offset=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>&nbsp;&nbsp; </span></font><span
lang=3DDA>bfp=3D0940e7f0 bln=3D32 avl=3D04 flg=3D05</span></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DDA =
style=3D'font-size:9.0pt'>&nbsp;&nbsp;
</span></font><span lang=3DPT-BR>value=3D&quot;8542&quot;</span></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DPT-BR =
style=3D'font-size:9.0pt'>EXEC
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1:
nam=3D'SQL*Net message to client' ela=3D 0 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1: nam=3D'file
open' ela=3D 0 p1=3D0 p2=3D0 p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1: nam=3D'db
file sequential read' ela=3D 0 p1=3D1 p2=3D6671 p3=3D1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1: nam=3D'db
file sequential read' ela=3D 0 p1=3D1 p2=3D6678 p3=3D1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span lang=3DPT-BR =
style=3D'font-size:9.0pt'>FETCH
#1:c=3D0,e=3D0,p=3D2,cr=3D3,cu=3D0,mis=3D0,r=3D1,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>*** =
2002-09-12
16:14:56.200</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>WAIT =
#1:
nam=3D'SQL*Net message from client' ela=3D 2496 p1=3D1650815232 p2=3D1 =
p3=3D0</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span =
style=3D'font-size:9.0pt'>XCTEND rlbk=3D0,
rd_only=3D1</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>STAT =
#1 id=3D1 cnt=3D1
pid=3D0 pos=3D0 obj=3D5156 op=3D'TABLE ACCESS BY INDEX ROWID T =
'</span></font></p>

<p class=3DCode style=3D'margin:0in;margin-bottom:.0001pt'><font =
size=3D1
color=3Dgreen face=3D"Courier New"><span style=3D'font-size:9.0pt'>STAT =
#1 id=3D2 cnt=3D2
pid=3D1 pos=3D1 obj=3D5157 op=3D'INDEX UNIQUE SCAN '</span></font></p>

</div>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>$ perl -V</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>Summary of my perl5 (revision 5.0 version 6 subversion 0) =
configuration:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Platform:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; osname=3Dlinux, osvers=3D2.2.5-22smp, =
archname=3Di386-linux</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; uname=3D'linux porky.devel.redhat.com =
2.2.5-22smp #1 smp
wed jun 2 </span></font>09:11:51 edt 1999 i686 unknown '</p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; config_args=3D'-des -Doptimize=3D-O2 =
-march=3Di386 -mcpu=3Di686
-Dcc=3Dgcc -Dcccdlflags=3D-fPIC -Dinstallprefix=3D/usr -Dprefix=3D/usr =
-Darchname=3Di386-linux
-Dd_dosuid -Dd_semctl_semun -Di_db -Di_ndbm -Di_gdbm -Di_shadow =
-Di_syslog -Dman3ext=3D</span></font>3pm -Uuselargefiles'</p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; hint=3Drecommended, useposix=3Dtrue, =
d_sigaction=3Ddefine</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; usethreads=3Dundef use5005threads=3Dundef =
useithreads=3Dundef
usemultiplicity=3Dundef</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; useperlio=3Dundef d_sfio=3Dundef =
uselargefiles=3Dundef </span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; use64bitint=3Dundef use64bitall=3Dundef =
uselongdouble=3Dundef
usesocks=3Dundef</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Compiler:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; cc=3D'gcc', optimize=3D'-O2 -march=3Di386 =
-mcpu=3Di686', gccversion=3D2.96
20000731 (experimental)</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; =
cppflags=3D'-fno-strict-aliasing'</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; ccflags =
=3D'-fno-strict-aliasing'</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; stdchar=3D'char', d_stdstdio=3Ddefine, =
usevfork=3Dfalse</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; intsize=3D4, longsize=3D4, ptrsize=3D4, =
doublesize=3D8</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; d_longlong=3Ddefine, longlongsize=3D8, =
d_longdbl=3Ddefine,
longdblsize=3D12</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; ivtype=3D'long', ivsize=3D4, =
nvtype=3D'double', nvsize=3D8, Off_t=3D'off_t',
lseeksize=3D4</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; alignbytes=3D4, usemymalloc=3Dn, =
prototype=3Ddefine</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Linker and Libraries:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; ld=3D'gcc', ldflags =3D' =
-L/usr/local/lib'</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; libpth=3D/usr/local/lib /lib =
/usr/lib</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; libs=3D-lnsl -ldl -lm -lc =
-lcrypt</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; libc=3D/lib/libc-2.1.92.so, so=3Dso, =
useshrplib=3Dfalse, libperl=3Dlibperl.a</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Dynamic Linking:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; dlsrc=3Ddl_dlopen.xs, dlext=3Dso, =
d_dlsymun=3Dundef, ccdlflags=3D'-rdynamic'</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; cccdlflags=3D'-fPIC', lddlflags=3D'-shared =
-L/usr/local/lib'</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>Characteristics of this binary (from libperl): =
</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Compile-time options:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Built under linux</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; Compiled at </span></font>Aug&nbsp; 7 2000 10:59:51</p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp; @INC:</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; =
/usr/lib/perl5/5.6.0/i386-linux</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; /usr/lib/perl5/5.6.0</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; =
/usr/lib/perl5/site_perl/5.6.0/i386-linux</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; =
/usr/lib/perl5/site_perl/5.6.0</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; /usr/lib/perl5/site_perl</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;&nbsp;&nbsp; .</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>Other site information</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>- </span></font>Redhat Linux 7.0</p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>- Oracle 8.1.6.1.0</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>- DBD-Oracle 1.12</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>- DBI 1.30</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

</div>

</body>

</html>

------=_NextPart_001_016B_01C25A80.D1557E70--

------=_NextPart_000_016A_01C25A80.D1527130
Content-Type: application/octet-stream;
	name="ex1.log"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: attachment;
	filename="ex1.log"

    DBI::db=3DHASH(0x8235a74) trace level set to 9 in DBI 1.30-nothread=0A=
    -> prepare for DBD::Oracle::db (DBI::db=3DHASH(0x8235b34)~0x8235a74 =
'alter session set events '10046 trace name context forever, level 12'')=0A=
    =
dbih_setup_handle(DBI::st=3DHASH(0x8240f68)=3D>DBI::st=3DHASH(0x8240f98),=
 DBD::Oracle::st, 8240f74, Null!)=0A=
    dbih_make_com(DBI::db=3DHASH(0x8235a74), DBD::Oracle::st, 208) =
thr#(nil)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), Err, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8162bb8) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), State, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8190e58) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), Errstr, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8162ba0) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), Debug, =
DBI::db=3DHASH(0x8235a74)) 9 (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), FetchHashKeyName, =
DBI::db=3DHASH(0x8235a74)) 'NAME' (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240f98), HandleError, =
DBI::db=3DHASH(0x8235a74)) undef (not defined)=0A=
OCIHandleAlloc(0x82465d8,0x826c948,OCI_HTYPE_STMT,0,(nil))=3DSUCCESS=0A=
OCIStmtPrepare(0x826bf48,0x82559ec,'alter session set events '10046 =
trace name context forever, level 12'',69,1,0)=3DSUCCESS=0A=
OCIAttrGet(0x826bf48,OCI_HTYPE_STMT,0x826c94c,(nil),24,0x82559ec)=3DSUCCE=
SS=0A=
    dbd_st_prepare'd sql ALTER=0A=
    dbd_describe skipped for ALTER=0A=
    <- prepare=3D DBI::st=3DHASH(0x8240f68) at ex1.pl line 38=0A=
    -> execute for DBD::Oracle::st (DBI::st=3DHASH(0x8240f68)~0x8240f98)=0A=
    dbd_st_execute ALTER (out0, lob0)...=0A=
OCIStmtExecute(0x82557c4,0x826bf48,0x82559ec,1,0,(nil),(nil),0)=3DSUCCESS=0A=
OCIAttrGet(0x826bf48,OCI_HTYPE_STMT,0xbffff654,(nil),9,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826bf48,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=3DSUCC=
ESS=0A=
    dbd_st_execute ALTER returned (SUCCESS, rpc0, fn52, out0)=0A=
    <- execute=3D '0E0' at ex1.pl line 39=0A=
    -> prepare for DBD::Oracle::db (DBI::db=3DHASH(0x8235b34)~0x8235a74 =
'select key, fkey, value from t where key=3D?')=0A=
    =
dbih_setup_handle(DBI::st=3DHASH(0x8240fe0)=3D>DBI::st=3DHASH(0x8240fb0),=
 DBD::Oracle::st, 8240fec, Null!)=0A=
    dbih_make_com(DBI::db=3DHASH(0x8235a74), DBD::Oracle::st, 208) =
thr#(nil)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), Err, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8162bb8) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), State, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8190e58) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), Errstr, =
DBI::db=3DHASH(0x8235a74)) SCALAR(0x8162ba0) (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), Debug, =
DBI::db=3DHASH(0x8235a74)) 9 (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), FetchHashKeyName, =
DBI::db=3DHASH(0x8235a74)) 'NAME' (already defined)=0A=
    dbih_setup_attrib(DBI::st=3DHASH(0x8240fb0), HandleError, =
DBI::db=3DHASH(0x8235a74)) undef (not defined)=0A=
    dbd_preparse scanned 1 distinct placeholders=0A=
OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=3DSUCCESS=0A=
OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t where =
key=3D:p1',44,1,0)=3DSUCCESS=0A=
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=3DSUCCE=
SS=0A=
    dbd_st_prepare'd sql SELECT=0A=
    dbd_describe SELECT (EXPLICIT, lb 80)...=0A=
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=3DSUCCES=
S=0A=
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff3dc,(nil),18,0x82559ec)=3DSUCC=
ESS=0A=
OCIParamGet(0x826e4a0,4,0x82559ec,0x826d1c0,1)=3DSUCCESS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1d6,(nil),2,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1d4,(nil),1,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1d8,(nil),5,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1da,(nil),6,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1db,(nil),7,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e228,OCI_DTYPE_PARAM,0x826d1e8,0xbffff3d8,4,0x82559ec)=3D=
SUCCESS=0A=
    fbh 1: 'KEY'	NO null , otype   2->  5, dbsize 22/134, p0.s0=0A=
OCIParamGet(0x826e4a0,4,0x82559ec,0x826d200,2)=3DSUCCESS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d216,(nil),2,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d214,(nil),1,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d218,(nil),5,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d21a,(nil),6,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d21b,(nil),7,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e208,OCI_DTYPE_PARAM,0x826d228,0xbffff3d8,4,0x82559ec)=3D=
SUCCESS=0A=
    fbh 2: 'FKEY'	NULLable, otype   2->  5, dbsize 22/134, p0.s0=0A=
OCIParamGet(0x826e4a0,4,0x82559ec,0x826d240,3)=3DSUCCESS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d256,(nil),2,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d254,(nil),1,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d258,(nil),5,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d25a,(nil),6,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d25b,(nil),7,0x82559ec)=3DSUCCE=
SS=0A=
OCIAttrGet(0x826e1e8,OCI_DTYPE_PARAM,0x826d268,0xbffff3d8,4,0x82559ec)=3D=
SUCCESS=0A=
    fbh 3: 'VALUE'	NULLable, otype   1->  5, dbsize 32/33, p32.s0=0A=
OCIAttrSet(0x826e4a0,OCI_HTYPE_STMT,0xbffff3d4,4,11,0x82559ec)=3DSUCCESS=0A=
OCIDefineByPos(0x826e4a0,0x826d1c4,0x82559ec,1,0x826e8d0,134,5,0x826d438,=
0x826d448,0x826d458,0)=3DSUCCESS=0A=
OCIDefineByPos(0x826e4a0,0x826d204,0x82559ec,2,0x826eaf8,134,5,0x826ca28,=
0x826ca38,0x826ca48,0)=3DSUCCESS=0A=
OCIDefineByPos(0x826e4a0,0x826d244,0x82559ec,3,0x826cbb8,33,5,0x826ca58,0=
x826cbe0,0x826cbf0,0)=3DSUCCESS=0A=
    dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache: 231)=0A=
    <- prepare=3D DBI::st=3DHASH(0x8240fe0) at ex1.pl line 50=0A=
    -> DESTROY for DBD::Oracle::st (DBI::st=3DHASH(0x8240f98)~INNER)=0A=
OCIHandleFree(0x826bf48,OCI_HTYPE_STMT)=3DSUCCESS=0A=
    <- DESTROY=3D undef at ex1.pl line 51=0A=
    -> execute for DBD::Oracle::st (DBI::st=3DHASH(0x8240fe0)~0x8240fb0 =
'8542')=0A=
       bind :p1 <=3D=3D '8542' (type 0)=0A=
       bind :p1 <=3D=3D '8542' (size 4/5/0, ptype 7, otype 1)=0A=
       bind :p1 <=3D=3D '8542' (size 4/4, otype 1, indp 0, at_exec 1)=0A=
OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826cb=
6e,(nil),0x826cb6c,0,(nil),2)=3DSUCCESS=0A=
OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401da=
090)=3DSUCCESS=0A=
       bind :p1 done with ftype 1=0A=
    dbd_st_execute SELECT (out0, lob0)...=0A=
       in  ':p1' [0,0]: len  4, ind 0=0A=
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=3DSUCCESS=0A=
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=3DSUCC=
ESS=0A=
    dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)=0A=
    <- execute=3D '0E0' at ex1.pl line 51=0A=
    -> fetchall_arrayref for DBD::Oracle::st =
(DBI::st=3DHASH(0x8240fe0)~0x8240fb0)=0A=
    dbd_st_fetch 3 fields...=0A=
OCIStmtFetch(0x826e4a0,0x82559ec,1,2,0)=3DSUCCESS=0A=
    dbih_setup_fbav for 3 fields =3D> 0x8240fbc=0A=
    dbd_st_fetch 3 fields SUCCESS=0A=
        0 (rc=3D0): '8542'=0A=
        1 (rc=3D0): '8542'=0A=
        2 (rc=3D0): 'value'=0A=
    dbd_st_fetch 3 fields...=0A=
OCIStmtFetch(0x826e4a0,0x82559ec,1,2,0)=3DNO_DATA=0A=
    dbd_st_fetch no-more-data=0A=
    <- fetchall_arrayref=3D [ ARRAY(0x82411f0) ] row1 at ex1.pl line 62=0A=
    -> disconnect for DBD::Oracle::db =
(DBI::db=3DHASH(0x8235b34)~0x8235a74)=0A=
OCISessionEnd(0x82557c4,0x82559ec,0x826c384,0)=3DSUCCESS=0A=
OCIServerDetach(0x8255834,0x82559ec,0)=3DSUCCESS=0A=
    <- disconnect=3D 1 at ex1.pl line 74=0A=
    -> DESTROY for DBD::Oracle::st (DBI::st=3DHASH(0x8240fb0)~INNER)=0A=
OCIHandleFree(0x826e4a0,OCI_HTYPE_STMT)=3DSUCCESS=0A=
    <- DESTROY=3D undef=0A=
    -> DESTROY for DBD::Oracle::db (DBI::db=3DHASH(0x8235a74)~INNER)=0A=
OCIHandleFree(0x826c384,OCI_HTYPE_SESSION)=3DSUCCESS=0A=
OCIHandleFree(0x8255834,OCI_HTYPE_SERVER)=3DSUCCESS=0A=
OCIHandleFree(0x82557c4,OCI_HTYPE_SVCCTX)=3DSUCCESS=0A=
OCIHandleFree(0x82559ec,OCI_HTYPE_ERROR)=3DSUCCESS=0A=
    <- DESTROY=3D undef=0A=

------=_NextPart_000_016A_01C25A80.D1527130--


From timbo@dansat.data-plan.com  Fri Sep 13 07:30:31 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8D6UUC04053
	for <timbo@localhost>; Fri, 13 Sep 2002 07:30:30 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 07:30:30 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031871608:20:03733:55; Thu, 12 Sep 2002 23:00:08 GMT
Received: from cali-3.pobox.com ([64.71.166.116]) by punt-2.mail.demon.net
           id ab2122693; 12 Sep 2002 23:00 GMT
Received: from cali-3.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-3.pobox.com (Postfix) with ESMTP id AE0642F0B8A
	for <Tim.Bunce@data-plan.com>; Thu, 12 Sep 2002 18:58:25 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail03.svc.cra.dublin.eircom.net (mail03.svc.cra.dublin.eircom.net [159.134.118.19])
	by cali-3.pobox.com (Postfix) with SMTP id 931D42F0D0A
	for <tim.bunce@pobox.com>; Thu, 12 Sep 2002 18:58:19 -0400 (EDT)
Received: (qmail 57270 messnum 519666 invoked from network[159.134.164.69/p69.as1.limerick1.eircom.net]); 12 Sep 2002 22:58:17 -0000
Received: from p69.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.164.69)
  by mail03.svc.cra.dublin.eircom.net (qp 57270) with SMTP; 12 Sep 2002 22:58:17 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g8CMwEQ02798;
	Thu, 12 Sep 2002 23:58:14 +0100 (BST)
	(envelope-from timbo)
Date: Thu, 12 Sep 2002 23:58:14 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Cary Millsap <cary.millsap@hotsos.com>
Cc: tim.bunce@pobox.com
Subject: two Oracle parse calls
Message-ID: <20020912225814.GG539@dansat.data-plan.com>
References: <016901c25aaa$ba287930$6501a8c0@CVMLAP01>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <016901c25aaa$ba287930$6501a8c0@CVMLAP01>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 3530
Lines: 77

On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap wrote:
> Tim,
> 
> How are you doing? I hope you've had a good two years since I saw you on
> the Oracle Geek Cruise event.

Yes thanks. And you?

> I've been working on a project this year to construct a book about
> optimizing Oracle response time. In my research, I've discovered
> something about the DBI that I didn't expect: it executes two Oracle
> parse calls for every one that I would expect an efficient DBI layer to
> make. I've included my Perl source (below), the Oracle level-12 trace
> data that shows the sequence of calls it's receiving from the Perl
> application (below), a level-9 DBI trace from the application
> (attached), and our version information (below).
> 
> I was hoping that by showing you this specific data, you could make the
> problem go away.

I can only do what OCI lets me do... but within that I'll do what I can...

I'm not familar with Oracle trace logs so I can't readily intrepret them
and I'll take what you say at face value.

But I am familar with DBD::Oracle :) and the logs it writes :)

> $sth = $dbh->prepare(q(select key, fkey, value from t where key=?));
> $sth->execute($key);


    -> prepare for DBD::Oracle::db (DBI::db=HASH(0x8235b34)~0x8235a74 'select key, fkey, value from t where key=?')
    dbd_preparse scanned 1 distinct placeholders
OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=SUCCESS
OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t where key=:p1',44,1,0)=SUCCESS
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=SUCCESS
    dbd_st_prepare'd sql SELECT
    dbd_describe SELECT (EXPLICIT, lb 80)...
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=SUCCESS
    dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache: 231)
    <- prepare= DBI::st=HASH(0x8240fe0) at ex1.pl line 50
    -> execute for DBD::Oracle::st (DBI::st=HASH(0x8240fe0)~0x8240fb0 '8542')
OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826cb6e,(nil),0x826cb6c,0,(nil),2)=SUCCESS
OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401da090)=SUCCESS
       bind :p1 done with ftype 1
    dbd_st_execute SELECT (out0, lob0)...
       in  ':p1' [0,0]: len  4, ind 0
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=SUCCESS
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=SUCCESS
    dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)
    <- execute= '0E0' at ex1.pl line 51

Given those OCI calls, what is DBD::Oracle doing that it shouldn't?

I'd guess that it's something to do with the OCIStmtExecute(..., OCI_DESCRIBE_ONLY)
call that prepare() does.

It doesn't do that for non-select statements so you could check if
non-selects also have two parse calls.

Also try doing
  $sth = $dbh->prepare(q(select key, fkey, value from t where key=?), { ora_check_sql=> 0 });

which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till after the
main OCIStmtExecute(). In that case the OCIStmtExecute(..., OCI_DESCRIBE_ONLY)
is possibly redundant and could be removed (but Oracle ought to detect that
anyway and not make a round-trip for it, and certainly not call parse).

If non-selects only have one parse call but ora_check_sql=>0 doesn't
fix selects, then I might be able to do a simple patch to avoid the
OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if ora_check_sql=>0.

Then the issue will be: should ora_check_sql=>0 be the default...

Tim.

p.s. I'd love a copy of your book when it's ready!

From cary.millsap@hotsos.com  Fri Sep 13 07:31:55 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8D6VsC04590
	for <timbo@localhost>; Fri, 13 Sep 2002 07:31:54 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 07:31:54 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031889643:20:09494:0; Fri, 13 Sep 2002 04:00:43 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-2.mail.demon.net
           id aa2008866; 13 Sep 2002 4:00 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id C94C67264F
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 00:00:07 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by wormwood.pobox.com (Postfix) with ESMTP id A821072676
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 00:00:06 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8D405n19404
	for <Tim.Bunce@pobox.com>; Thu, 12 Sep 2002 23:00:05 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: two Oracle parse calls
Date: Thu, 12 Sep 2002 22:59:56 -0500
Message-ID: <019201c25ada$093c6ac0$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
In-Reply-To: <20020912225814.GG539@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 4825
Lines: 129

Tim,

Thanks so very much. The attribute ora_check_sql=>0 is new knowledge to
me; this is a nice reward for having written to you. I will test it
either tonight or the first thing tomorrow and then inform you of the
results immediately after that. If it solves the problem, then I will
lobby you to make 0 the default value and probably consider the issue
"problem solved."

Things are very well, thank you. I've been at home with my family now
for over three straight weeks, and we're having a nice time of our lives
these days with the business settling into stride a bit. Tonight is a
big night for me. I've just crossed the line of accepting a preliminary
offer from O'Reilly. This book project has actually been underway for
quite some time now, but as of tonight it's quite a bit more "official."


Cary Millsap
Hotsos Enterprises, Ltd.
http://www.hotsos.com

Upcoming events:
- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
Honolulu
- 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
- Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark



-----Original Message-----
From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
Sent: Thursday, September 12, 2002 5:58 PM
To: Cary Millsap
Cc: tim.bunce@pobox.com
Subject: two Oracle parse calls

On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap wrote:
> Tim,
> 
> How are you doing? I hope you've had a good two years since I saw you
on
> the Oracle Geek Cruise event.

Yes thanks. And you?

> I've been working on a project this year to construct a book about
> optimizing Oracle response time. In my research, I've discovered
> something about the DBI that I didn't expect: it executes two Oracle
> parse calls for every one that I would expect an efficient DBI layer
to
> make. I've included my Perl source (below), the Oracle level-12 trace
> data that shows the sequence of calls it's receiving from the Perl
> application (below), a level-9 DBI trace from the application
> (attached), and our version information (below).
> 
> I was hoping that by showing you this specific data, you could make
the
> problem go away.

I can only do what OCI lets me do... but within that I'll do what I
can...

I'm not familar with Oracle trace logs so I can't readily intrepret them
and I'll take what you say at face value.

But I am familar with DBD::Oracle :) and the logs it writes :)

> $sth = $dbh->prepare(q(select key, fkey, value from t where key=?));
> $sth->execute($key);


    -> prepare for DBD::Oracle::db (DBI::db=HASH(0x8235b34)~0x8235a74
'select key, fkey, value from t where key=?')
    dbd_preparse scanned 1 distinct placeholders
OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=SUCCESS
OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t where
key=:p1',44,1,0)=SUCCESS
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=SUCCES
S
    dbd_st_prepare'd sql SELECT
    dbd_describe SELECT (EXPLICIT, lb 80)...
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=SUCCESS
    dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache: 231)
    <- prepare= DBI::st=HASH(0x8240fe0) at ex1.pl line 50
    -> execute for DBD::Oracle::st (DBI::st=HASH(0x8240fe0)~0x8240fb0
'8542')
OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826c
b6e,(nil),0x826cb6c,0,(nil),2)=SUCCESS
OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401d
a090)=SUCCESS
       bind :p1 done with ftype 1
    dbd_st_execute SELECT (out0, lob0)...
       in  ':p1' [0,0]: len  4, ind 0
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=SUCCESS
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=SUCCE
SS
    dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)
    <- execute= '0E0' at ex1.pl line 51

Given those OCI calls, what is DBD::Oracle doing that it shouldn't?

I'd guess that it's something to do with the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)
call that prepare() does.

It doesn't do that for non-select statements so you could check if
non-selects also have two parse calls.

Also try doing
  $sth = $dbh->prepare(q(select key, fkey, value from t where key=?), {
ora_check_sql=> 0 });

which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till after the
main OCIStmtExecute(). In that case the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)
is possibly redundant and could be removed (but Oracle ought to detect
that
anyway and not make a round-trip for it, and certainly not call parse).

If non-selects only have one parse call but ora_check_sql=>0 doesn't
fix selects, then I might be able to do a simple patch to avoid the
OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if ora_check_sql=>0.

Then the issue will be: should ora_check_sql=>0 be the default...

Tim.

p.s. I'd love a copy of your book when it's ready!


From timbo@dansat.data-plan.com  Fri Sep 13 10:48:59 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8D9mwC06022
	for <timbo@localhost>; Fri, 13 Sep 2002 10:48:58 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 10:48:58 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031907122:20:19599:21; Fri, 13 Sep 2002 08:52:02 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-2.mail.demon.net
           id aa2129553; 13 Sep 2002 8:52 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP id 99E263E660
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 04:51:54 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail03.svc.cra.dublin.eircom.net (mail03.svc.cra.dublin.eircom.net [159.134.118.19])
	by cali-2.pobox.com (Postfix) with SMTP id 721613E637
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 04:51:53 -0400 (EDT)
Received: (qmail 29161 messnum 524631 invoked from network[159.134.167.5/p773.as1.limerick1.eircom.net]); 13 Sep 2002 08:51:51 -0000
Received: from p773.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.167.5)
  by mail03.svc.cra.dublin.eircom.net (qp 29161) with SMTP; 13 Sep 2002 08:51:51 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g8D8prO05752;
	Fri, 13 Sep 2002 09:51:53 +0100 (BST)
	(envelope-from timbo)
Date: Fri, 13 Sep 2002 09:51:53 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Cary Millsap <cary.millsap@hotsos.com>
Cc: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: Re: two Oracle parse calls
Message-ID: <20020913085153.GJ539@dansat.data-plan.com>
References: <20020912225814.GG539@dansat.data-plan.com> <019201c25ada$093c6ac0$6501a8c0@CVMLAP01>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <019201c25ada$093c6ac0$6501a8c0@CVMLAP01>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 6172
Lines: 154

On Thu, Sep 12, 2002 at 10:59:56PM -0500, Cary Millsap wrote:
> Tim,
> 
> Thanks so very much. The attribute ora_check_sql=>0 is new knowledge to
> me; this is a nice reward for having written to you. I will test it
> either tonight or the first thing tomorrow and then inform you of the
> results immediately after that. If it solves the problem, then I will
> lobby you to make 0 the default value and probably consider the issue
> "problem solved."

Ah, but there are down-sides to ora_check_sql=0 - it was the default
for a little while. Here's an old message that, although being out of
date in various ways, describes some of the issues:

http://www.bitmechanic.com/mail-archives/dbi-users/Apr1999/0538.html

In principle I don't have a fundamental objection to defering the
'describe' until execute and thus defering detection of syntax
errors until the execute. I'd probably add a new $dbh attribute to
set the desired default behaviour so you don't have to add it to
each prepare() call.

> Things are very well, thank you. I've been at home with my family now
> for over three straight weeks, and we're having a nice time of our lives
> these days with the business settling into stride a bit. Tonight is a
> big night for me. I've just crossed the line of accepting a preliminary
> offer from O'Reilly. This book project has actually been underway for
> quite some time now, but as of tonight it's quite a bit more "official."

Congratulations. I'm sure it'll be a success.

BTW, if you happen to come across any work opportunities that might
fit my skills I'd be interested in hearing about them (would have to
be teleworking as I've no plans to move under any circumstances).
I'd especially love to find some company that uses DBI & DBD::Oracle
heavily and would basically pay me to develop them - there's *lots*
more valuable functionality that could be added to DBD::Oracle (and
my Oracle::OCI module).

Tim.

> 
> Cary Millsap
> Hotsos Enterprises, Ltd.
> http://www.hotsos.com
> 
> Upcoming events:
> - Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
> Honolulu
> - 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
> - Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark
> 
> 
> 
> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
> Sent: Thursday, September 12, 2002 5:58 PM
> To: Cary Millsap
> Cc: tim.bunce@pobox.com
> Subject: two Oracle parse calls
> 
> On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap wrote:
> > Tim,
> > 
> > How are you doing? I hope you've had a good two years since I saw you
> on
> > the Oracle Geek Cruise event.
> 
> Yes thanks. And you?
> 
> > I've been working on a project this year to construct a book about
> > optimizing Oracle response time. In my research, I've discovered
> > something about the DBI that I didn't expect: it executes two Oracle
> > parse calls for every one that I would expect an efficient DBI layer
> to
> > make. I've included my Perl source (below), the Oracle level-12 trace
> > data that shows the sequence of calls it's receiving from the Perl
> > application (below), a level-9 DBI trace from the application
> > (attached), and our version information (below).
> > 
> > I was hoping that by showing you this specific data, you could make
> the
> > problem go away.
> 
> I can only do what OCI lets me do... but within that I'll do what I
> can...
> 
> I'm not familar with Oracle trace logs so I can't readily intrepret them
> and I'll take what you say at face value.
> 
> But I am familar with DBD::Oracle :) and the logs it writes :)
> 
> > $sth = $dbh->prepare(q(select key, fkey, value from t where key=?));
> > $sth->execute($key);
> 
> 
>     -> prepare for DBD::Oracle::db (DBI::db=HASH(0x8235b34)~0x8235a74
> 'select key, fkey, value from t where key=?')
>     dbd_preparse scanned 1 distinct placeholders
> OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=SUCCESS
> OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t where
> key=:p1',44,1,0)=SUCCESS
> OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=SUCCES
> S
>     dbd_st_prepare'd sql SELECT
>     dbd_describe SELECT (EXPLICIT, lb 80)...
> OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=SUCCESS
>     dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache: 231)
>     <- prepare= DBI::st=HASH(0x8240fe0) at ex1.pl line 50
>     -> execute for DBD::Oracle::st (DBI::st=HASH(0x8240fe0)~0x8240fb0
> '8542')
> OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826c
> b6e,(nil),0x826cb6c,0,(nil),2)=SUCCESS
> OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401d
> a090)=SUCCESS
>        bind :p1 done with ftype 1
>     dbd_st_execute SELECT (out0, lob0)...
>        in  ':p1' [0,0]: len  4, ind 0
> OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=SUCCESS
> OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=SUCCE
> SS
>     dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)
>     <- execute= '0E0' at ex1.pl line 51
> 
> Given those OCI calls, what is DBD::Oracle doing that it shouldn't?
> 
> I'd guess that it's something to do with the OCIStmtExecute(...,
> OCI_DESCRIBE_ONLY)
> call that prepare() does.
> 
> It doesn't do that for non-select statements so you could check if
> non-selects also have two parse calls.
> 
> Also try doing
>   $sth = $dbh->prepare(q(select key, fkey, value from t where key=?), {
> ora_check_sql=> 0 });
> 
> which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till after the
> main OCIStmtExecute(). In that case the OCIStmtExecute(...,
> OCI_DESCRIBE_ONLY)
> is possibly redundant and could be removed (but Oracle ought to detect
> that
> anyway and not make a round-trip for it, and certainly not call parse).
> 
> If non-selects only have one parse call but ora_check_sql=>0 doesn't
> fix selects, then I might be able to do a simple patch to avoid the
> OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if ora_check_sql=>0.
> 
> Then the issue will be: should ora_check_sql=>0 be the default...
> 
> Tim.
> 
> p.s. I'd love a copy of your book when it's ready!
> 

From cary.millsap@hotsos.com  Fri Sep 13 17:52:40 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DGqdC10778
	for <timbo@localhost>; Fri, 13 Sep 2002 17:52:39 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 17:52:39 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031932999:10:25604:102; Fri, 13 Sep 2002 16:03:19 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1101673; 13 Sep 2002 16:03 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id E4A692C078
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 12:02:43 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by dolly1.pobox.com (Postfix) with ESMTP id 1609E2C03F
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 12:02:29 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8DG2Sn24856
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 11:02:28 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: two Oracle parse calls
Date: Fri, 13 Sep 2002 11:02:20 -0500
Message-ID: <01c501c25b3e$f3e7f440$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
In-Reply-To: <20020913085153.GJ539@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 9234
Lines: 248

Tim,

I think it's important for a developer to have the ability to turn this
on and off. But I would argue that 0 is the correct default. I think of
it as a probability times cost function. The cost of leaving the setting
at 1 accidentally in a production application is pretty high: if the app
doesn't scale (because it's parsing too much), then it jeopardizes the
business' ability to succeed with it.

The probability of leaving the option set to 1 accidentally during
production is very high. A point in evidence is that I didn't find the
parameter until I corresponded personally with you. I in fact *still*
don't know where to find it. I've checked Descartes & Bunce, perldoc
DBI, and perldoc DBD::Oracle without finding it yet...

If the default were 0, the probability of leaving the option set to 0
accidentally during development would be much lower. A developer faced
with a SQL syntax problem he doesn't understand will do the research
necessary to fix that problem. He can't release his code until he does.

The problem with the default of 1 is, in my opinion, that most
developers will never learn of the feature, and they'll accidentally
leave it turned on in production. The proportion of developers who
competently performance-test their code is, unfortunately,
microscopically small. But they all do some level of functional testing.

I would recommend making the ora_check_sql feature a more prominently
documented feature, presumably in "perldoc DBD::Oracle".

I did learn in a test that specifying the option in the DBI->connect()
call doesn't do anything. Is it possible that you could allow us to
specify it at the connection level? The workaround is to do something
like this:

	use Getopt::Long;
	my %prepare_attr = (ora_check_sql=>0);
	GetOptions("dev"=>\$dev);
	$prepare_attr{ora_check_sql} = 1 if $dev;
	# developer must specify the command-line flag to get the
unscalable
	# behavior that's necessary for functional testing
	...
	$sth = $dbh->prepare($sql, %prepare_attr);  # MUST specify
%p..attr

...But I doubt that most Oracle application developers would come up
with this without some coaching.

I'll definitely keep an eye open for projects you might like. It would
be a hell of an opportunity for someone to have you, I think. It seems
that if you could make a list like Oracle-L (1,900 people) aware that
there's an opportunity, it would improve your chances of finding
something quickly. It's of course bad taste to advertise oneself overtly
on those lists, but there is almost always a clever way to do it anyway
without offending anyone.


Cary Millsap
Hotsos Enterprises, Ltd.
http://www.hotsos.com

Upcoming events:
- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
Honolulu
- 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
- Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark



-----Original Message-----
From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
Sent: Friday, September 13, 2002 3:52 AM
To: Cary Millsap
Cc: 'Tim Bunce'
Subject: Re: two Oracle parse calls

On Thu, Sep 12, 2002 at 10:59:56PM -0500, Cary Millsap wrote:
> Tim,
> 
> Thanks so very much. The attribute ora_check_sql=>0 is new knowledge
to
> me; this is a nice reward for having written to you. I will test it
> either tonight or the first thing tomorrow and then inform you of the
> results immediately after that. If it solves the problem, then I will
> lobby you to make 0 the default value and probably consider the issue
> "problem solved."

Ah, but there are down-sides to ora_check_sql=0 - it was the default
for a little while. Here's an old message that, although being out of
date in various ways, describes some of the issues:

http://www.bitmechanic.com/mail-archives/dbi-users/Apr1999/0538.html

In principle I don't have a fundamental objection to defering the
'describe' until execute and thus defering detection of syntax
errors until the execute. I'd probably add a new $dbh attribute to
set the desired default behaviour so you don't have to add it to
each prepare() call.

> Things are very well, thank you. I've been at home with my family now
> for over three straight weeks, and we're having a nice time of our
lives
> these days with the business settling into stride a bit. Tonight is a
> big night for me. I've just crossed the line of accepting a
preliminary
> offer from O'Reilly. This book project has actually been underway for
> quite some time now, but as of tonight it's quite a bit more
"official."

Congratulations. I'm sure it'll be a success.

BTW, if you happen to come across any work opportunities that might
fit my skills I'd be interested in hearing about them (would have to
be teleworking as I've no plans to move under any circumstances).
I'd especially love to find some company that uses DBI & DBD::Oracle
heavily and would basically pay me to develop them - there's *lots*
more valuable functionality that could be added to DBD::Oracle (and
my Oracle::OCI module).

Tim.

> 
> Cary Millsap
> Hotsos Enterprises, Ltd.
> http://www.hotsos.com
> 
> Upcoming events:
> - Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
> Honolulu
> - 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
> - Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark
> 
> 
> 
> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
> Sent: Thursday, September 12, 2002 5:58 PM
> To: Cary Millsap
> Cc: tim.bunce@pobox.com
> Subject: two Oracle parse calls
> 
> On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap wrote:
> > Tim,
> > 
> > How are you doing? I hope you've had a good two years since I saw
you
> on
> > the Oracle Geek Cruise event.
> 
> Yes thanks. And you?
> 
> > I've been working on a project this year to construct a book about
> > optimizing Oracle response time. In my research, I've discovered
> > something about the DBI that I didn't expect: it executes two Oracle
> > parse calls for every one that I would expect an efficient DBI layer
> to
> > make. I've included my Perl source (below), the Oracle level-12
trace
> > data that shows the sequence of calls it's receiving from the Perl
> > application (below), a level-9 DBI trace from the application
> > (attached), and our version information (below).
> > 
> > I was hoping that by showing you this specific data, you could make
> the
> > problem go away.
> 
> I can only do what OCI lets me do... but within that I'll do what I
> can...
> 
> I'm not familar with Oracle trace logs so I can't readily intrepret
them
> and I'll take what you say at face value.
> 
> But I am familar with DBD::Oracle :) and the logs it writes :)
> 
> > $sth = $dbh->prepare(q(select key, fkey, value from t where key=?));
> > $sth->execute($key);
> 
> 
>     -> prepare for DBD::Oracle::db (DBI::db=HASH(0x8235b34)~0x8235a74
> 'select key, fkey, value from t where key=?')
>     dbd_preparse scanned 1 distinct placeholders
> OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=SUCCESS
> OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t
where
> key=:p1',44,1,0)=SUCCESS
>
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=SUCCES
> S
>     dbd_st_prepare'd sql SELECT
>     dbd_describe SELECT (EXPLICIT, lb 80)...
>
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=SUCCESS
>     dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache:
231)
>     <- prepare= DBI::st=HASH(0x8240fe0) at ex1.pl line 50
>     -> execute for DBD::Oracle::st (DBI::st=HASH(0x8240fe0)~0x8240fb0
> '8542')
>
OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826c
> b6e,(nil),0x826cb6c,0,(nil),2)=SUCCESS
>
OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401d
> a090)=SUCCESS
>        bind :p1 done with ftype 1
>     dbd_st_execute SELECT (out0, lob0)...
>        in  ':p1' [0,0]: len  4, ind 0
>
OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=SUCCESS
>
OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=SUCCE
> SS
>     dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)
>     <- execute= '0E0' at ex1.pl line 51
> 
> Given those OCI calls, what is DBD::Oracle doing that it shouldn't?
> 
> I'd guess that it's something to do with the OCIStmtExecute(...,
> OCI_DESCRIBE_ONLY)
> call that prepare() does.
> 
> It doesn't do that for non-select statements so you could check if
> non-selects also have two parse calls.
> 
> Also try doing
>   $sth = $dbh->prepare(q(select key, fkey, value from t where key=?),
{
> ora_check_sql=> 0 });
> 
> which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till after the
> main OCIStmtExecute(). In that case the OCIStmtExecute(...,
> OCI_DESCRIBE_ONLY)
> is possibly redundant and could be removed (but Oracle ought to detect
> that
> anyway and not make a round-trip for it, and certainly not call
parse).
> 
> If non-selects only have one parse call but ora_check_sql=>0 doesn't
> fix selects, then I might be able to do a simple patch to avoid the
> OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if ora_check_sql=>0.
> 
> Then the issue will be: should ora_check_sql=>0 be the default...
> 
> Tim.
> 
> p.s. I'd love a copy of your book when it's ready!
> 


From timbo@dansat.data-plan.com  Fri Sep 13 23:21:37 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DMLbC13725
	for <timbo@localhost>; Fri, 13 Sep 2002 23:21:37 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 23:21:37 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031951069:20:15816:152; Fri, 13 Sep 2002 21:04:29 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-2.mail.demon.net
           id aa2120669; 13 Sep 2002 21:04 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP id 544863E642
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 17:04:17 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail05.svc.cra.dublin.eircom.net (mail05.svc.cra.dublin.eircom.net [159.134.118.21])
	by cali-2.pobox.com (Postfix) with SMTP id 0AE7C3E667
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 17:04:16 -0400 (EDT)
Received: (qmail 16221 messnum 355694 invoked from network[159.134.166.226/p738.as1.limerick1.eircom.net]); 13 Sep 2002 21:04:14 -0000
Received: from p738.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.166.226)
  by mail05.svc.cra.dublin.eircom.net (qp 16221) with SMTP; 13 Sep 2002 21:04:14 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g8DL4Lx12642;
	Fri, 13 Sep 2002 22:04:21 +0100 (BST)
	(envelope-from timbo)
Date: Fri, 13 Sep 2002 22:04:21 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Cary Millsap <cary.millsap@hotsos.com>
Cc: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: Re: two Oracle parse calls
Message-ID: <20020913210421.GR539@dansat.data-plan.com>
References: <20020913085153.GJ539@dansat.data-plan.com> <01c501c25b3e$f3e7f440$6501a8c0@CVMLAP01>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <01c501c25b3e$f3e7f440$6501a8c0@CVMLAP01>
User-Agent: Mutt/1.4i
Status: O
Content-Length: 3078
Lines: 70

On Fri, Sep 13, 2002 at 11:02:20AM -0500, Cary Millsap wrote:
> Tim,
> 
> I think it's important for a developer to have the ability to turn this
> on and off. But I would argue that 0 is the correct default. I think of
> it as a probability times cost function. The cost of leaving the setting
> at 1 accidentally in a production application is pretty high: if the app
> doesn't scale (because it's parsing too much), then it jeopardizes the
> business' ability to succeed with it.
> 
> The probability of leaving the option set to 1 accidentally during
> production is very high. A point in evidence is that I didn't find the
> parameter until I corresponded personally with you. I in fact *still*
> don't know where to find it. I've checked Descartes & Bunce, perldoc
> DBI, and perldoc DBD::Oracle without finding it yet...

It's not documented.

As I recall it... originally DBD::Oracle defered the describe as
long as possible.  But people reported very slow select performance:

  http://www.faqchest.com/prgm/dbi-l/dbi-99/dbi-9910/dbi-991005/dbi99101218_28018.html

Turned out that the row cache logic needed the describe to try to
work out an optimal row cache size. Without the describe the row
cache wasn't getting set up.

At some point I added code that would just set OCI_ATTR_PREFETCH_MEMORY
to a set size if ora_check_sql was 0. But I can't remember now why
I left ora_check_sql=1.

It was possibly in relation to wanting to be able to use the
OCI_ATTR_PARSE_ERROR_OFFSET attribute to be able to highlight the
point in a query where the error was detected. But I think execute()
needs to be able to do that anyway (to catch syntax errors in
non-select statements).

There is another problem. If the describe has been defered and the
application uses $sth->{NAME} or other similar attribute then the
describe has to be done at that point. The code is thee to do that
but the problem is how should the DBI behave if there's an error
in the SQL? It currently always croaks (rather than return undef,
in order to give a useful error message), but that's rather surprising
behaviour to many people and very unhelpful to some.

There may well be other subtle issues that I can't recall right now.

> I would recommend making the ora_check_sql feature a more prominently
> documented feature, presumably in "perldoc DBD::Oracle".
> 
> I did learn in a test that specifying the option in the DBI->connect()
> call doesn't do anything. Is it possible that you could allow us to
> specify it at the connection level?

By making it a database handle attribute, yes, that would be my plan.

> I'll definitely keep an eye open for projects you might like. It would
> be a hell of an opportunity for someone to have you, I think.

Thanks.

> It seems that if you could make a list like Oracle-L (1,900 people) aware
> that there's an opportunity, it would improve your chances of finding
> something quickly. It's of course bad taste to advertise oneself overtly
> on those lists, but there is almost always a clever way to do it anyway
> without offending anyone.

:-)

Tim.

From cary.millsap@hotsos.com  Fri Sep 13 07:32:06 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8D6W1C04656
	for <timbo@localhost>; Fri, 13 Sep 2002 07:32:01 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 07:32:01 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031891038:20:04710:44; Fri, 13 Sep 2002 04:23:58 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-2.mail.demon.net
           id ab2004623; 13 Sep 2002 4:23 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 942A82BF2C
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 00:23:44 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by dolly1.pobox.com (Postfix) with ESMTP id 73C982BF33
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 00:23:42 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8D4Ndn19584
	for <Tim.Bunce@pobox.com>; Thu, 12 Sep 2002 23:23:39 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: two Oracle parse calls
Date: Thu, 12 Sep 2002 23:23:30 -0500
Message-ID: <019301c25add$53f5dfd0$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0194_01C25AB3.6B1FD7D0"
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
In-Reply-To: 
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
Content-Length: 36859
Lines: 1209

This is a multi-part message in MIME format.

------=_NextPart_000_0194_01C25AB3.6B1FD7D0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

Well, that was easy. Setting ora_check_sql=>0 does solve the problem.

 

I now shift into "Please make 0 the default" mode.

 

Here are the Oracle trace files, by the way, with a splash of color to
illustrate how the Oracle kernel sees what's going on (I hope you have
an HTML mail reader)...

 

With {ora_check_sql=>1} (or no setting at all), here's what Oracle does
for the application:

 

=====================

PARSING IN CURSOR #2 len=44 dep=0 uid=12 oct=3 lid=12 tim=107312018
hv=1997601641 ad='54af1384'

select key, fkey, value from t where key=:p1

END OF STMT

PARSE #2:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312018

=====================

PARSING IN CURSOR #1 len=44 dep=0 uid=12 oct=3 lid=12 tim=107312019
hv=1997601641 ad='54af1384'

select key, fkey, value from t where key=:p1

END OF STMT

PARSE #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312019

EXEC #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=107312019

FETCH #1:c=0,e=0,p=2,cr=3,cu=0,mis=0,r=1,dep=0,og=3,tim=107312019

 

The PARSING IN CURSOR section tells us what SQL it is that we're
executing. Each line beginning with "PARSE" is emitted only when Oracle
executes a parse call. There are two. The first is wasted.

 

Here's the same application with {ora_check_sql=>1} (the official new
default value, I am sure :-)):

 

=====================

PARSING IN CURSOR #1 len=44 dep=0 uid=12 oct=3 lid=12 tim=109776065
hv=1997601641 ad='54af1384'

select key, fkey, value from t where key=:p1

END OF STMT

PARSE #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=109776065

EXEC #1:c=0,e=0,p=0,cr=0,cu=0,mis=0,r=0,dep=0,og=3,tim=109776065

FETCH #1:c=0,e=0,p=0,cr=3,cu=0,mis=0,r=1,dep=0,og=3,tim=109776065

 

One parse call; problem solved.

 

Thank you sincerely for your help.

 

 

Cary Millsap

Hotsos Enterprises, Ltd.

http://www.hotsos.com

 

Upcoming events:

- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
Honolulu

- 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas

- Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark

 

 

 

-----Original Message-----
From: Cary Millsap [mailto:cary.millsap@hotsos.com] 
Sent: Thursday, September 12, 2002 11:00 PM
To: 'Tim Bunce'
Subject: RE: two Oracle parse calls

 

Tim,

 

Thanks so very much. The attribute ora_check_sql=>0 is new knowledge to
me; this is a nice reward for having written to you. I will test it
either tonight or the first thing tomorrow and then inform you of the
results immediately after that. If it solves the problem, then I will
lobby you to make 0 the default value and probably consider the issue
"problem solved."

 

Things are very well, thank you. I've been at home with my family now
for over three straight weeks, and we're having a nice time of our lives
these days with the business settling into stride a bit. Tonight is a
big night for me. I've just crossed the line of accepting a preliminary
offer from O'Reilly. This book project has actually been underway for
quite some time now, but as of tonight it's quite a bit more "official."

 

 

Cary Millsap

Hotsos Enterprises, Ltd.

http://www.hotsos.com

 

Upcoming events:

- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
Honolulu

- 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas

- Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark

 

 

 

-----Original Message-----

From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 

Sent: Thursday, September 12, 2002 5:58 PM

To: Cary Millsap

Cc: tim.bunce@pobox.com

Subject: two Oracle parse calls

 

On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap wrote:

> Tim,

> 

> How are you doing? I hope you've had a good two years since I saw you
on

> the Oracle Geek Cruise event.

 

Yes thanks. And you?

 

> I've been working on a project this year to construct a book about

> optimizing Oracle response time. In my research, I've discovered

> something about the DBI that I didn't expect: it executes two Oracle

> parse calls for every one that I would expect an efficient DBI layer
to

> make. I've included my Perl source (below), the Oracle level-12 trace

> data that shows the sequence of calls it's receiving from the Perl

> application (below), a level-9 DBI trace from the application

> (attached), and our version information (below).

> 

> I was hoping that by showing you this specific data, you could make
the

> problem go away.

 

I can only do what OCI lets me do... but within that I'll do what I
can...

 

I'm not familar with Oracle trace logs so I can't readily intrepret them

and I'll take what you say at face value.

 

But I am familar with DBD::Oracle :) and the logs it writes :)

 

> $sth = $dbh->prepare(q(select key, fkey, value from t where key=?));

> $sth->execute($key);

 

 

    -> prepare for DBD::Oracle::db (DBI::db=HASH(0x8235b34)~0x8235a74
'select key, fkey, value from t where key=?')

    dbd_preparse scanned 1 distinct placeholders

OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=SUCCESS

OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from t where
key=:p1',44,1,0)=SUCCESS

OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=SUCCES
S

    dbd_st_prepare'd sql SELECT

    dbd_describe SELECT (EXPLICIT, lb 80)...

OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=SUCCESS

    dbd_describe'd 3 columns (row bytes: 76 max, 40 est avg, cache: 231)

    <- prepare= DBI::st=HASH(0x8240fe0) at ex1.pl line 50

    -> execute for DBD::Oracle::st (DBI::st=HASH(0x8240fe0)~0x8240fb0
'8542')

OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,":p1",3,0x826cd78,4,1,0x826c
b6e,(nil),0x826cb6c,0,(nil),2)=SUCCESS

OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40,0x401d
a090)=SUCCESS

       bind :p1 done with ftype 1

    dbd_st_execute SELECT (out0, lob0)...

       in  ':p1' [0,0]: len  4, ind 0

OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=SUCCESS

OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec)=SUCCE
SS

    dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)

    <- execute= '0E0' at ex1.pl line 51

 

Given those OCI calls, what is DBD::Oracle doing that it shouldn't?

 

I'd guess that it's something to do with the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)

call that prepare() does.

 

It doesn't do that for non-select statements so you could check if

non-selects also have two parse calls.

 

Also try doing

  $sth = $dbh->prepare(q(select key, fkey, value from t where key=?), {
ora_check_sql=> 0 });

 

which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till after the

main OCIStmtExecute(). In that case the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)

is possibly redundant and could be removed (but Oracle ought to detect
that

anyway and not make a round-trip for it, and certainly not call parse).

 

If non-selects only have one parse call but ora_check_sql=>0 doesn't

fix selects, then I might be able to do a simple patch to avoid the

OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if ora_check_sql=>0.

 

Then the issue will be: should ora_check_sql=>0 be the default...

 

Tim.

 

p.s. I'd love a copy of your book when it's ready!


------=_NextPart_000_0194_01C25AB3.6B1FD7D0
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>

<head>
<META HTTP-EQUIV=3D"Content-Type" CONTENT=3D"text/html; =
charset=3Dus-ascii">


<meta name=3DGenerator content=3D"Microsoft Word 10 (filtered)">

<style>
<!--
 /* Font Definitions */
 @font-face
	{font-family:Wingdings;
	panose-1:5 0 0 0 0 0 0 0 0 0;}
 /* Style Definitions */
 p.MsoNormal, li.MsoNormal, div.MsoNormal
	{margin:0in;
	margin-bottom:.0001pt;
	font-size:12.0pt;
	font-family:"Times New Roman";}
a:link, span.MsoHyperlink
	{color:blue;
	text-decoration:underline;}
a:visited, span.MsoHyperlinkFollowed
	{color:purple;
	text-decoration:underline;}
p.MsoPlainText, li.MsoPlainText, div.MsoPlainText
	{margin:0in;
	margin-bottom:.0001pt;
	font-size:10.0pt;
	font-family:"Courier New";}
p
	{margin-right:0in;
	margin-left:0in;
	font-size:12.0pt;
	font-family:"Times New Roman";}
span.EmailStyle19
	{font-family:Arial;
	color:windowtext;}
@page Section1
	{size:8.5in 11.0in;
	margin:1.0in 77.95pt 1.0in 77.95pt;}
div.Section1
	{page:Section1;}
-->
</style>

</head>

<body lang=3DEN-US link=3Dblue vlink=3Dpurple>

<div class=3DSection1>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Well, that was easy. Setting ora_check_sql=3D&gt;0 =
does solve the
problem.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>I now shift into &quot;Please make 0 the =
default&quot; mode.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Here are the Oracle trace files, by the way, with a =
splash
of color to illustrate how the Oracle kernel sees what&#8217;s going on =
(I hope
you have an HTML mail reader)...</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>With </span></font><font size=3D1><span =
style=3D'font-size:9.0pt'>{ora_check_sql=3D&gt;1}</span></font><font
face=3DArial><span style=3D'font-family:Arial'> (or no setting at all), =
here&#8217;s
what Oracle does for the application:</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D</s=
pan></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:red'>PARSING IN CURSOR #2 len=3D44 dep=3D0 uid=3D12 =
oct=3D3 lid=3D12 </span></font><font
 size=3D1><span =
style=3D'font-size:9.0pt;background:red'>tim</span></font><font
size=3D1><span style=3D'font-size:9.0pt;background:red'>=3D107312018 =
hv=3D1997601641 ad=3D'54af1384'</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:red'>select key, fkey, value from t where =
key=3D:p1</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:red'>END OF STMT</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:red'>PARSE =
#2:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312018</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D</s=
pan></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:yellow'>PARSING IN CURSOR #1 len=3D44 dep=3D0 uid=3D12 =
oct=3D3 lid=3D12 </span></font><font
 size=3D1><span =
style=3D'font-size:9.0pt;background:yellow'>tim</span></font><font
size=3D1><span style=3D'font-size:9.0pt;background:yellow'>=3D107312019 =
hv=3D1997601641
ad=3D'54af1384'</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:
9.0pt;background:yellow'>select key, fkey, value from t where =
key=3D:p1</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
lang=3DDA
style=3D'font-size:9.0pt;background:yellow'>END OF =
STMT</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
lang=3DDA
style=3D'font-size:9.0pt;background:yellow'>PARSE =
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
lang=3DPT-BR
style=3D'font-size:9.0pt;background:yellow'>EXEC =
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DMsoPlainText><font size=3D1 face=3D"Courier New"><span =
lang=3DPT-BR
style=3D'font-size:9.0pt;background:yellow'>FETCH =
#1:c=3D0,e=3D0,p=3D2,cr=3D3,cu=3D0,mis=3D0,r=3D1,dep=3D0,og=3D3,tim=3D107=
312019</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
lang=3DPT-BR
style=3D'font-size:10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>The PARSING IN CURSOR section tells us what SQL it is =
that
we&#8217;re executing. Each line beginning with &#8220;PARSE&#8221; is =
emitted
only when Oracle executes a parse call. There are two. The first is =
wasted.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Here&#8217;s the same application with =
</span></font><font
size=3D1><span =
style=3D'font-size:9.0pt'>{ora_check_sql=3D&gt;1}</span></font><font
face=3DArial><span style=3D'font-family:Arial'> (the official new =
default value, I
am sure </span></font><font face=3DWingdings><span =
style=3D'font-family:Wingdings'>J</span></font><font
face=3DArial><span style=3D'font-family:Arial'>):</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;
font-family:"Courier =
New"'>=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D</sp=
an></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;
font-family:"Courier New";background:lime'>PARSING IN CURSOR #1 len=3D44 =
dep=3D0 uid=3D12
oct=3D3 lid=3D12 </span></font><font size=3D1 face=3D"Courier New"><span
 style=3D'font-size:9.0pt;font-family:"Courier =
New";background:lime'>tim</span></font><font
size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;font-family:"Courier New";
background:lime'>=3D109776065 hv=3D1997601641 =
ad=3D'54af1384'</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;
font-family:"Courier New";background:lime'>select key, fkey, value from =
t where
key=3D:p1</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;
font-family:"Courier New";background:lime'>END OF STMT</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
style=3D'font-size:9.0pt;
font-family:"Courier New";background:lime'>PARSE =
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D109=
776065</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
lang=3DPT-BR
style=3D'font-size:9.0pt;font-family:"Courier New";background:lime'>EXEC =
#1:c=3D0,e=3D0,p=3D0,cr=3D0,cu=3D0,mis=3D0,r=3D0,dep=3D0,og=3D3,tim=3D109=
776065</span></font></p>

<p class=3DMsoNormal><font size=3D1 face=3D"Courier New"><span =
lang=3DPT-BR
style=3D'font-size:9.0pt;font-family:"Courier =
New";background:lime'>FETCH =
#1:c=3D0,e=3D0,p=3D0,cr=3D3,cu=3D0,mis=3D0,r=3D1,dep=3D0,og=3D3,tim=3D109=
776065</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span lang=3DPT-BR
style=3D'font-size:10.0pt;font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>One parse call; problem solved.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Thank you sincerely for your help.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><b><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
   font-family:Arial;font-weight:bold'>Cary</span></font></b><b><font
face=3DArial><span style=3D'font-family:Arial;font-weight:bold'> =
Millsap</span></font></b></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Hotsos Enterprises, Ltd.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>http://www.hotsos.com</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>Upcoming events:</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>- Hotsos Clinic, Oct 1-3 </span></font><font =
face=3DArial><span
  style=3D'font-family:Arial'>San Francisco</span></font><font =
face=3DArial><span
style=3D'font-family:Arial'>, Oct 15-17 </span></font><font =
face=3DArial><span
   style=3D'font-family:Arial'>Dallas</span></font><font =
face=3DArial><span
style=3D'font-family:Arial'>, Dec 9-11 </span></font><font =
face=3DArial><span
  style=3D'font-family:Arial'>Honolulu</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>- 2003 Hotsos Symposium on Oracle&reg; System =
Performance,
Feb 9-12 </span></font><font face=3DArial><span =
style=3D'font-family:Arial'>Dallas</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>- Next event: Miracle Database Forum, Sep 20-22 =
Middelfart </span></font><font
  face=3DArial><span =
style=3D'font-family:Arial'>Denmark</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>-----Original Message-----<br>
From: Cary Millsap [mailto:cary.millsap@hotsos.com] <br>
Sent: Thursday, September 12, 2002 11:00 PM<br>
To: 'Tim Bunce'<br>
Subject: RE: two Oracle parse calls</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Tim,</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Thanks so very much. The attribute ora_check_sql=3D&gt;0 is new =
knowledge
to me; this is a nice reward for having written to you. I will test it =
either
tonight or the first thing tomorrow and then inform you of the results
immediately after that. If it solves the problem, then I will lobby you =
to make
0 the default value and probably consider the issue &quot;problem =
solved.&quot;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Things are very well, thank you. I've been at home with my =
family now
for over three straight weeks, and we're having a nice time of our lives =
these
days with the business settling into stride a bit. Tonight is a big =
night for
me. I've just crossed the line of accepting a preliminary offer from =
O'Reilly.
This book project has actually been underway for quite some time now, =
but as of
tonight it's quite a bit more &quot;official.&quot;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Cary Millsap</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Hotsos Enterprises, Ltd.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>http://www.hotsos.com</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Upcoming events:</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec =
9-11
Honolulu</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>- 2003 Hotsos Symposium on Oracle&reg; System Performance, Feb =
9-12
Dallas</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>- Next event: Miracle Database Forum, Sep 20-22 Middelfart =
Denmark</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>-----Original Message-----</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>From: Tim Bunce [mailto:Tim.Bunce@pobox.com] </span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Sent: Thursday, September 12, 2002 5:58 PM</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>To: Cary Millsap</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Cc: tim.bunce@pobox.com</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Subject: two Oracle parse calls</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>On Thu, Sep 12, 2002 at 05:21:17PM -0500, Cary Millsap =
wrote:</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; Tim,</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; </span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; How are you doing? I hope you've had a good two years since =
I saw
you on</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; the Oracle Geek Cruise event.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Yes thanks. And you?</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; I've been working on a project this year to construct a =
book about</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; optimizing Oracle response time. In my research, I've =
discovered</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; something about the DBI that I didn't expect: it executes =
two
Oracle</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; parse calls for every one that I would expect an efficient =
DBI
layer to</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; make. I've included my Perl source (below), the Oracle =
level-12
trace</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; data that shows the sequence of calls it's receiving from =
the Perl</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; application (below), a level-9 DBI trace from the =
application</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; (attached), and our version information =
(below).</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; </span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; I was hoping that by showing you this specific data, you =
could
make the</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; problem go away.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>I can only do what OCI lets me do... but within that I'll do =
what I
can...</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>I'm not familar with Oracle trace logs so I can't readily =
intrepret
them</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>and I'll take what you say at face value.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>But I am familar with DBD::Oracle :) and the logs it writes =
:)</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; $sth =3D $dbh-&gt;prepare(q(select key, fkey, value from t =
where
key=3D?));</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&gt; $sth-&gt;execute($key);</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; -&gt; prepare for DBD::Oracle::db
(DBI::db=3DHASH(0x8235b34)~0x8235a74 'select key, fkey, value from t =
where
key=3D?')</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_preparse scanned 1 distinct =
placeholders</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIHandleAlloc(0x82465d8,0x826cae8,OCI_HTYPE_STMT,0,(nil))=3DSUCC=
ESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIStmtPrepare(0x826e4a0,0x82559ec,'select key, fkey, value from =
t
where key=3D:p1',44,1,0)=3DSUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0x826caec,(nil),24,0x82559ec)=
=3DSUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_st_prepare'd sql SELECT</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_describe SELECT (EXPLICIT, lb =
80)...</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),16)=3D=
SUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_describe'd 3 columns (row bytes: 76 max, =
40 est
avg, cache: 231)</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; &lt;- prepare=3D DBI::st=3DHASH(0x8240fe0) at =
ex1.pl
line 50</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; -&gt; execute for DBD::Oracle::st
(DBI::st=3DHASH(0x8240fe0)~0x8240fb0 '8542')</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIBindByName(0x826e4a0,0x826cb5c,0x82559ec,&quot;:p1&quot;,3,0x8=
26cd78,4,1,0x826cb6e,(nil),0x826cb6c,0,(nil),2)=3DSUCCESS</span></font></=
p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIBindDynamic(0x826dc40,0x82559ec,0x826cb40,0x401d9f60,0x826cb40=
,0x401da090)=3DSUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; bind :p1 done with ftype =
1</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_st_execute SELECT (out0, =
lob0)...</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; in&nbsp; ':p1' [0,0]: =
len&nbsp; 4,
ind 0</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIStmtExecute(0x82557c4,0x826e4a0,0x82559ec,0,0,(nil),(nil),0)=3D=
SUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIAttrGet(0x826e4a0,OCI_HTYPE_STMT,0xbffff65a,(nil),10,0x82559ec=
)=3DSUCCESS</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; dbd_st_execute SELECT returned (SUCCESS, =
rpc0, fn4,
out0)</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;&nbsp;&nbsp; &lt;- execute=3D '0E0' at ex1.pl line =
51</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Given those OCI calls, what is DBD::Oracle doing that it =
shouldn't?</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>I'd guess that it's something to do with the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>call that prepare() does.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>It doesn't do that for non-select statements so you could check =
if</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>non-selects also have two parse calls.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Also try doing</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp; $sth =3D $dbh-&gt;prepare(q(select key, fkey, value from =
t where
key=3D?), { ora_check_sql=3D&gt; 0 });</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>which refers the OCIStmtExecute(..., OCI_DESCRIBE_ONLY) till =
after the</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>main OCIStmtExecute(). In that case the OCIStmtExecute(...,
OCI_DESCRIBE_ONLY)</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>is possibly redundant and could be removed (but Oracle ought to =
detect
that</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>anyway and not make a round-trip for it, and certainly not call =
parse).</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>If non-selects only have one parse call but =
ora_check_sql=3D&gt;0 doesn't</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>fix selects, then I might be able to do a simple patch to avoid =
the</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>OCIStmtExecute(..., OCI_DESCRIBE_ONLY) if =
ora_check_sql=3D&gt;0.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Then the issue will be: should ora_check_sql=3D&gt;0 be the =
default...</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>Tim.</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>&nbsp;</span></font></p>

<p class=3DMsoPlainText><font size=3D2 face=3D"Courier New"><span =
style=3D'font-size:
10.0pt'>p.s. I'd love a copy of your book when it's =
ready!</span></font></p>

</div>

</body>

</html>

------=_NextPart_000_0194_01C25AB3.6B1FD7D0--


From cary.millsap@hotsos.com  Fri Sep 13 21:17:44 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DKHhC12417
	for <timbo@localhost>; Fri, 13 Sep 2002 21:17:43 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 21:17:43 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031946929:20:18513:70; Fri, 13 Sep 2002 19:55:29 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-2.mail.demon.net
           id aa2018248; 13 Sep 2002 19:55 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 7FC402C01F
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 15:55:06 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by dolly1.pobox.com (Postfix) with ESMTP id 76A5E2BFE1
	for <tim.bunce@pobox.com>; Fri, 13 Sep 2002 15:55:05 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8DJt4n26736
	for <tim.bunce@pobox.com>; Fri, 13 Sep 2002 14:55:04 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: "Tim Bunce" <tim.bunce@pobox.com>
Subject: A little more data
Date: Fri, 13 Sep 2002 14:54:56 -0500
Message-ID: <020201c25b5f$7248a760$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: multipart/alternative;
	boundary="----=_NextPart_000_0203_01C25B35.89729F60"
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 4948
Lines: 166

This is a multi-part message in MIME format.

------=_NextPart_000_0203_01C25B35.89729F60
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

Tim,

 

I hope this is helpful. I have noticed that I cannot produce the
extra-parse problem on my 8.1.7 laptop database, no matter what the
setting of ora_check_sql. All of the data I've sent you is from our
8.1.6 Linux database. If you really needed it, I could produce level-9
DBI trace data from identical tests on both platforms, but I won't spend
the time doing that unless you say it will help...

 

Cary Millsap
Hotsos Enterprises, Ltd.
http://www.hotsos.com

Upcoming events:
- Hotsos Clinic <http://www.hotsos.com/training/clinic> , Oct 1-3 San
Francisco, Oct 15-17 Dallas, Dec 9-11 Honolulu
- 2003 Hotsos Symposium <http://www.hotsos.com/events/symposium>  on
OracleR System Performance, Feb 9-12 Dallas
- Next event: Miracle Database Forum <http://www.miracleas.dk> , Sep
20-22 Middlefart Denmark

 


------=_NextPart_000_0203_01C25B35.89729F60
Content-Type: text/html;
	charset="us-ascii"
Content-Transfer-Encoding: quoted-printable

<html>

<head>
<META HTTP-EQUIV=3D"Content-Type" CONTENT=3D"text/html; =
charset=3Dus-ascii">


<meta name=3DGenerator content=3D"Microsoft Word 10 (filtered)">

<style>
<!--
 /* Style Definitions */
 p.MsoNormal, li.MsoNormal, div.MsoNormal
	{margin:0in;
	margin-bottom:.0001pt;
	font-size:12.0pt;
	font-family:"Times New Roman";}
a:link, span.MsoHyperlink
	{color:blue;
	text-decoration:underline;}
a:visited, span.MsoHyperlinkFollowed
	{color:purple;
	text-decoration:underline;}
p
	{margin-right:0in;
	margin-left:0in;
	font-size:12.0pt;
	font-family:"Times New Roman";}
span.EmailStyle17
	{font-family:Arial;
	color:windowtext;}
@page Section1
	{size:8.5in 11.0in;
	margin:1.0in 1.25in 1.0in 1.25in;}
div.Section1
	{page:Section1;}
-->
</style>

</head>

<body lang=3DEN-US link=3Dblue vlink=3Dpurple>

<div class=3DSection1>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
 font-family:Arial'>Tim</span></font><font size=3D2 face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'>,</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>I hope this is helpful&#8230; I have noticed that I =
cannot
produce the extra-parse problem on my 8.1.7 laptop database, no matter =
what the
setting of ora_check_sql. All of the data I&#8217;ve sent you is from =
our 8.1.6
Linux database. If you really needed it, I could produce level-9 DBI =
trace data
from identical tests on both platforms, but I won&#8217;t spend the time =
doing
that unless you say it will help...</span></font></p>

<p class=3DMsoNormal><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
font-family:Arial'>&nbsp;</span></font></p>

<p><b><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial;
   font-weight:bold'>Cary</span></font></b><b><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial;font-weight:bold'> =
Millsap</span></font></b><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'><br>
Hotsos Enterprises, Ltd.<br>
<a href=3D"http://www.hotsos.com">http://www.hotsos.com</a><br>
<br>
Upcoming events:<br>
- <a href=3D"http://www.hotsos.com/training/clinic">Hotsos Clinic</a>, =
Oct
1&#8211;3 </span></font><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
  font-family:Arial'>San Francisco</span></font><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'>, Oct 15&#8211;17 =
</span></font><font
   size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>Dallas</span></font><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>, Dec
9&#8211;11 </span></font><font size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;
  font-family:Arial'>Honolulu</span></font><font size=3D2 =
face=3DArial><span
style=3D'font-size:10.0pt;font-family:Arial'><br>
- <a href=3D"http://www.hotsos.com/events/symposium">2003 Hotsos =
Symposium</a> on
Oracle<sup>&reg;</sup> System Performance, Feb 9&#8211;12 =
</span></font><font
   size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'>Dallas</span></font><font
size=3D2 face=3DArial><span =
style=3D'font-size:10.0pt;font-family:Arial'><br>
- Next event: <a href=3D"http://www.miracleas.dk">Miracle Database =
Forum</a>, Sep
20&#8211;22 Middlefart </span></font><font size=3D2 face=3DArial><span
  style=3D'font-size:10.0pt;font-family:Arial'>Denmark</span></font></p>

<p class=3DMsoNormal><font size=3D3 face=3D"Times New Roman"><span =
style=3D'font-size:
12.0pt'>&nbsp;</span></font></p>

</div>

</body>

</html>

------=_NextPart_000_0203_01C25B35.89729F60--


From timbo@dansat.data-plan.com  Fri Sep 13 22:05:30 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DL5UC12942
	for <timbo@localhost>; Fri, 13 Sep 2002 22:05:30 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 22:05:30 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031948458:10:20432:5; Fri, 13 Sep 2002 20:20:58 GMT
Received: from cali-2.pobox.com ([64.71.166.115]) by punt-1.mail.demon.net
           id aa1020174; 13 Sep 2002 20:20 GMT
Received: from cali-2.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-2.pobox.com (Postfix) with ESMTP id 8A60E3E659
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 16:20:41 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail05.svc.cra.dublin.eircom.net (mail05.svc.cra.dublin.eircom.net [159.134.118.21])
	by cali-2.pobox.com (Postfix) with SMTP id CAC663E685
	for <tim.bunce@pobox.com>; Fri, 13 Sep 2002 16:20:36 -0400 (EDT)
Received: (qmail 37861 messnum 258096 invoked from network[159.134.164.124/p124.as1.limerick1.eircom.net]); 13 Sep 2002 20:20:35 -0000
Received: from p124.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.164.124)
  by mail05.svc.cra.dublin.eircom.net (qp 37861) with SMTP; 13 Sep 2002 20:20:35 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g8DKKhu12535;
	Fri, 13 Sep 2002 21:20:43 +0100 (BST)
	(envelope-from timbo)
Date: Fri, 13 Sep 2002 21:20:43 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Cary Millsap <cary.millsap@hotsos.com>
Cc: Tim Bunce <tim.bunce@pobox.com>
Subject: Re: A little more data
Message-ID: <20020913202043.GO539@dansat.data-plan.com>
References: <020201c25b5f$7248a760$6501a8c0@CVMLAP01>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <020201c25b5f$7248a760$6501a8c0@CVMLAP01>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 1098
Lines: 34

If they're using the same version of DBD::Oracle then
the change must me on the sever side. Maybe Oracle's
woken up to the fact they don't need a second parse!

Tim.

On Fri, Sep 13, 2002 at 02:54:56PM -0500, Cary Millsap wrote:
> Tim,
> 
>  
> 
> I hope this is helpful. I have noticed that I cannot produce the
> extra-parse problem on my 8.1.7 laptop database, no matter what the
> setting of ora_check_sql. All of the data I've sent you is from our
> 8.1.6 Linux database. If you really needed it, I could produce level-9
> DBI trace data from identical tests on both platforms, but I won't spend
> the time doing that unless you say it will help...
> 
>  
> 
> Cary Millsap
> Hotsos Enterprises, Ltd.
> http://www.hotsos.com
> 
> Upcoming events:
> - Hotsos Clinic <http://www.hotsos.com/training/clinic> , Oct 1-3 San
> Francisco, Oct 15-17 Dallas, Dec 9-11 Honolulu
> - 2003 Hotsos Symposium <http://www.hotsos.com/events/symposium>  on
> OracleR System Performance, Feb 9-12 Dallas
> - Next event: Miracle Database Forum <http://www.miracleas.dk> , Sep
> 20-22 Middlefart Denmark
> 
>  
> 

From cary.millsap@hotsos.com  Fri Sep 13 22:04:47 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DL4kC12684
	for <timbo@localhost>; Fri, 13 Sep 2002 22:04:46 +0100 (BST)
	(envelope-from cary.millsap@hotsos.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 22:04:46 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031949629:20:13745:23; Fri, 13 Sep 2002 20:40:29 GMT
Received: from cali-1.pobox.com ([64.71.166.114]) by punt-2.mail.demon.net
           id aa2013849; 13 Sep 2002 20:40 GMT
Received: from cali-1.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-1.pobox.com (Postfix) with ESMTP id 7D90A3E650
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 16:40:20 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from www.hotsos.com (unknown [63.145.61.17])
	by cali-1.pobox.com (Postfix) with ESMTP id 785AB3E642
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 16:40:19 -0400 (EDT)
Received: from CVMLAP01 (66-169-133-3.ftwrth.tx.charter.com [66.169.133.3])
	(authenticated (0 bits))
	by www.hotsos.com (8.11.3/8.11.0) with ESMTP id g8DKeIn27106
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 15:40:18 -0500
From: "Cary Millsap" <cary.millsap@hotsos.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: A little more data
Date: Fri, 13 Sep 2002 15:40:10 -0500
Message-ID: <020d01c25b65$c4056e70$6501a8c0@CVMLAP01>
MIME-Version: 1.0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook, Build 10.0.3416
Importance: Normal
In-Reply-To: <20020913202043.GO539@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 1999
Lines: 63

Well, it's 1.06 on my Windows machine (the most up-to-date version
available from ActiveState), and 1.12 on Linux. Not exactly a fair test,
but interesting that (admitting now that there's a new degree of freedom
running loose amid the test) "the older version performs better than the
newer one." :) That's certainly not a fair statement if the diff between
8.1.6 and 8.1.7 OCI is the root cause of the behavior difference.


Cary Millsap
Hotsos Enterprises, Ltd.
http://www.hotsos.com

Upcoming events:
- Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
Honolulu
- 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
- Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark



-----Original Message-----
From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
Sent: Friday, September 13, 2002 3:21 PM
To: Cary Millsap
Cc: Tim Bunce
Subject: Re: A little more data

If they're using the same version of DBD::Oracle then
the change must me on the sever side. Maybe Oracle's
woken up to the fact they don't need a second parse!

Tim.

On Fri, Sep 13, 2002 at 02:54:56PM -0500, Cary Millsap wrote:
> Tim,
> 
>  
> 
> I hope this is helpful. I have noticed that I cannot produce the
> extra-parse problem on my 8.1.7 laptop database, no matter what the
> setting of ora_check_sql. All of the data I've sent you is from our
> 8.1.6 Linux database. If you really needed it, I could produce level-9
> DBI trace data from identical tests on both platforms, but I won't
spend
> the time doing that unless you say it will help...
> 
>  
> 
> Cary Millsap
> Hotsos Enterprises, Ltd.
> http://www.hotsos.com
> 
> Upcoming events:
> - Hotsos Clinic <http://www.hotsos.com/training/clinic> , Oct 1-3 San
> Francisco, Oct 15-17 Dallas, Dec 9-11 Honolulu
> - 2003 Hotsos Symposium <http://www.hotsos.com/events/symposium>  on
> OracleR System Performance, Feb 9-12 Dallas
> - Next event: Miracle Database Forum <http://www.miracleas.dk> , Sep
> 20-22 Middlefart Denmark
> 
>  
> 


From timbo@dansat.data-plan.com  Fri Sep 13 23:21:32 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g8DMLWC13692
	for <timbo@localhost>; Fri, 13 Sep 2002 23:21:32 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 13 Sep 2002 23:21:32 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1031952887:10:13297:20; Fri, 13 Sep 2002 21:34:47 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1118141; 13 Sep 2002 21:34 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id C7D482BF23
	for <Tim.Bunce@data-plan.com>; Fri, 13 Sep 2002 17:34:38 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail00.svc.cra.dublin.eircom.net (mail00.svc.cra.dublin.eircom.net [159.134.118.16])
	by dolly1.pobox.com (Postfix) with SMTP id 8352A2BF6C
	for <Tim.Bunce@pobox.com>; Fri, 13 Sep 2002 17:34:36 -0400 (EDT)
Received: (qmail 5093 messnum 521124 invoked from network[159.134.164.134/p134.as1.limerick1.eircom.net]); 13 Sep 2002 21:34:34 -0000
Received: from p134.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.164.134)
  by mail00.svc.cra.dublin.eircom.net (qp 5093) with SMTP; 13 Sep 2002 21:34:34 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g8DLYeI13070;
	Fri, 13 Sep 2002 22:34:40 +0100 (BST)
	(envelope-from timbo)
Date: Fri, 13 Sep 2002 22:34:40 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Cary Millsap <cary.millsap@hotsos.com>
Cc: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: Re: A little more data
Message-ID: <20020913213440.GS539@dansat.data-plan.com>
References: <20020913202043.GO539@dansat.data-plan.com> <020d01c25b65$c4056e70$6501a8c0@CVMLAP01>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <020d01c25b65$c4056e70$6501a8c0@CVMLAP01>
User-Agent: Mutt/1.4i
Status: O
Content-Length: 2282
Lines: 69

According my RCS the default for ora_check_sql changed from 0 to 1
around version 1.03.

Tim.

On Fri, Sep 13, 2002 at 03:40:10PM -0500, Cary Millsap wrote:
> Well, it's 1.06 on my Windows machine (the most up-to-date version
> available from ActiveState), and 1.12 on Linux. Not exactly a fair test,
> but interesting that (admitting now that there's a new degree of freedom
> running loose amid the test) "the older version performs better than the
> newer one." :) That's certainly not a fair statement if the diff between
> 8.1.6 and 8.1.7 OCI is the root cause of the behavior difference.
> 
> 
> Cary Millsap
> Hotsos Enterprises, Ltd.
> http://www.hotsos.com
> 
> Upcoming events:
> - Hotsos Clinic, Oct 1-3 San Francisco, Oct 15-17 Dallas, Dec 9-11
> Honolulu
> - 2003 Hotsos Symposium on OracleR System Performance, Feb 9-12 Dallas
> - Next event: Miracle Database Forum, Sep 20-22 Middelfart Denmark
> 
> 
> 
> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com] 
> Sent: Friday, September 13, 2002 3:21 PM
> To: Cary Millsap
> Cc: Tim Bunce
> Subject: Re: A little more data
> 
> If they're using the same version of DBD::Oracle then
> the change must me on the sever side. Maybe Oracle's
> woken up to the fact they don't need a second parse!
> 
> Tim.
> 
> On Fri, Sep 13, 2002 at 02:54:56PM -0500, Cary Millsap wrote:
> > Tim,
> > 
> >  
> > 
> > I hope this is helpful. I have noticed that I cannot produce the
> > extra-parse problem on my 8.1.7 laptop database, no matter what the
> > setting of ora_check_sql. All of the data I've sent you is from our
> > 8.1.6 Linux database. If you really needed it, I could produce level-9
> > DBI trace data from identical tests on both platforms, but I won't
> spend
> > the time doing that unless you say it will help...
> > 
> >  
> > 
> > Cary Millsap
> > Hotsos Enterprises, Ltd.
> > http://www.hotsos.com
> > 
> > Upcoming events:
> > - Hotsos Clinic <http://www.hotsos.com/training/clinic> , Oct 1-3 San
> > Francisco, Oct 15-17 Dallas, Dec 9-11 Honolulu
> > - 2003 Hotsos Symposium <http://www.hotsos.com/events/symposium>  on
> > OracleR System Performance, Feb 9-12 Dallas
> > - Next event: Miracle Database Forum <http://www.miracleas.dk> , Sep
> > 20-22 Middlefart Denmark
> > 
> >  
> > 
> 

