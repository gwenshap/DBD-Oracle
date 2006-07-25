From SRS0=YmHr=OD=systransoft.com=cassidy@bounce2.pobox.com  Wed Nov 17 19:08:49 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id iAHJ8F8P027204
	for <timbo@localhost>; Wed, 17 Nov 2004 19:08:48 GMT
	(envelope-from SRS0=YmHr=OD=systransoft.com=cassidy@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 17 Nov 2004 19:08:48 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CUUU6-0001mQ-FU;
	Wed, 17 Nov 2004 18:24:50 +0000
Received: from [194.217.242.71] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CUUU6-0001mQ-FU
	for pobox@data-plan.com; Wed, 17 Nov 2004 18:24:50 +0000
Received: from [207.8.226.3] (helo=icicle.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1CUUU6-0000DF-68
	for pobox@data-plan.com; Wed, 17 Nov 2004 18:24:50 +0000
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 9D10A120BFA;
	Wed, 17 Nov 2004 13:24:49 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from icicle (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 8C898120BEF
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 17 Nov 2004 13:24:49 -0500 (EST)
Received-SPF: none (icicle.pobox.com: domain of cassidy@systransoft.com does not designate permitted sender hosts)
X-SPF-Guess: pass (seems reasonable for cassidy@systransoft.com to mail through 66.185.164.3)
Received: from mailhost.systransoft.com (mailhost.systransoft.com [66.185.164.3])
	by icicle.pobox.com (Postfix) with ESMTP id 362C6120BEC
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 13:24:46 -0500 (EST)
Received: from localhost (localhost [127.0.0.1])
	by mailhost.systransoft.com (Postfix) with ESMTP id 9C0CC244379
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 10:24:44 -0800 (PST)
Received: from mailhost.systransoft.com ([127.0.0.1])
 by localhost (mailhost.systransoft.com [127.0.0.1]) (amavisd-new, port 10024)
 with ESMTP id 17196-06 for <Tim.Bunce@pobox.com>;
 Wed, 17 Nov 2004 10:24:44 -0800 (PST)
Received: from hapax (hapax [192.168.2.186])
	by mailhost.systransoft.com (Postfix) with ESMTP id 3131324406F
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 10:24:44 -0800 (PST)
From: "Susan Cassidy" <cassidy@systransoft.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: FW: DBD::Oracle and strange problem with Oracle error 'ORA-01461: can bind a LONG value only for insert into a LONG column' when data not LONG
Date: Wed, 17 Nov 2004 10:22:44 -0800
Organization: SYSTRAN Software, Inc.
MIME-Version: 1.0
Content-Type: multipart/mixed;
	boundary="----=_NextPart_000_006A_01C4CC8F.60A4F6F0"
X-Mailer: Microsoft Office Outlook, Build 11.0.5510
In-Reply-To: <20041117173321.GA6272@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2800.1441
Thread-Index: AcTMy6HoelzJHh9WSPaTpCdfuF1C4gABpsZg
Message-Id: <20041117182444.3131324406F@mailhost.systransoft.com>
X-Virus-Scanned: by amavisd-new at systransoft.com
Status: RO
Content-Length: 16865
Lines: 527

This is a multi-part message in MIME format.

------=_NextPart_000_006A_01C4CC8F.60A4F6F0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit

I did - it is attached to the posting.  However, I will attach it again
here.

Thanks,
Susan

> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> Sent: Wednesday, November 17, 2004 9:33 AM
> To: Susan Cassidy
> Cc: dbi-users@perl.org
> Subject: Re: FW: DBD::Oracle and strange problem with Oracle error 'ORA-
> 01461: can bind a LONG value only for insert into a LONG column' when data
> not LONG
> 
> If you can post a small self-contained example that demonstrates
> the problem then I'll take a look.
> 
> Tim.
> 
> On Wed, Nov 17, 2004 at 09:15:52AM -0800, Susan Cassidy wrote:
> >    I never got any response to my question about this problem.  I
> thought I'd try again.
> >
> >
> >
> >    This is DBD::Oracle 1.16, DBI 1.45, Oracle 9i (9.2), Linux, Perl
> 5.8.5.
> >
> >
> >
> >    Thanks,
> >
> >    Susan
> >
> >
> >
> >    ---------------------------------------------------------------------
> -----------------------------------
> >
> >    From: Susan Cassidy [mailto:cassidy@systransoft.com]
> >    Sent: Friday, November 05, 2004 10:23 AM
> >    To: 'dbi-users@perl.org'
> >    Subject: DBD::Oracle and strange problem with Oracle error 'ORA-
> 01461: can bind a LONG value only for
> >    insert into a LONG column' when data not LONG
> >
> >
> >
> >    I had an application that was processing a bunch of xml and inserting
> into a table with a bunch of
> >    VARCHAR2(4000) columns.
> >
> >
> >
> >    A couple of the entries I was processing caused the 'ORA-01461: can
> bind a LONG value only for insert
> >    into a LONG column' error.
> >
> >
> >
> >    I put checks in for the length of the data, and nothing approached
> 4000 bytes in length.
> >
> >
> >
> >    I tracked down some of the entries causing problems, and on certain
> specific data, if 2 columns
> >    containing specific data are inserted together, I get this error.  If
> only one of the 2 is inserted, I
> >    do not get the error, regardless of which one of the two I insert.
> >
> >
> >
> >    The lengths of the pieces of data are 1399 and 1397 characters.
> >
> >
> >
> >    The data is somewhat odd-looking (we suspect some odd data is in this
> file), but there is no reason for
> >    the error message to appear.
> >
> >
> >
> >    Trace shows nothing helpful - it thinks the data is the right length.
> >
> >
> >
> >    We've successfully inserted thousands of other, similar entries with
> no trouble.
> >
> >
> >
> >    The basics are:
> >
> >    #create table test_table (item1 varchar2(4000), item2
> varchar2(4000));
> >
> >
> >
> >    my $statement="INSERT INTO test_table (item1,item2) VALUES (?, ?)";
> >
> >
> >
> >      $sth=$dbh->prepare($statement) ||
> >
> >        errexit("bad prepare for stmt $statement, error: $DBI::errstr");
> >
> >      my $rc=$sth->execute(@vals) ||
> >
> >        errexit("can't execute statement: error: $DBI::errstr\n");
> >
> >
> >
> >    Trace shows:
> >
> >
> >
> >        DBI 1.45-ithread default trace level set to 0x0/2 (pid 6230)
> >
> >        -> prepare for DBD::Oracle::db (DBI::db=HASH(0x82d4178)~0x82d6580
> 'INSERT INTO test_table
> >    (item1,item2) VALUES (?, ?)
> >
> >    ') thr#8148ff0
> >
> >        dbd_preparse scanned 2 distinct placeholders
> >
> >        <- prepare= DBI::st=HASH(0x82d6640) at test_insert_large.pl line
> 40
> >
> >        -> execute for DBD::Oracle::st (DBI::st=HASH(0x82d6640)~0x8149dcc
> 'version 11.2no service
> >    password-encryptionservice
> >
> >    udp-small-serversservice tcp-small-servers!hostname router1!!no ip
> domain-lookupip inspect name mysite
> >    ftpip inspect name
> >
> >     mysite smtpip inspect name mysite tcp!interface Ethernet0ip address
> 10.10.10.2 255.255.255.0ip
> >    access-group 101 inip ins
> >
> >    pect mysite inip inspect mysite outno keepalive!interface Serial0no
> ip addressencapsulation
> >    frame-relay...' 'version 11.2
> >
> >    no service password-encryptionservice udp-small-serversservice tcp-
> small-servers!hostname router1!!no ip
> >    domain-lookupip
> >
> >    inspect name mysite ftpip inspect name mysite smtpip inspect name
> mysite tcp!interface Ethernet0ip
> >    address 10.10.10.2 255
> >
> >    .255.255.0ip access-group 101 inip inspect mysiteinip inspect mysite
> outno keepalive!interface Serial0no
> >    ip addressencaps
> >
> >    ulation frame-relayn...') thr#8148ff0
> >
> >           bind :p1 <== 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostnam
> >
> >    e router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface E
> >
> >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysite inip inspect mysite
> >    outno keepalive!in
> >
> >    terface Serial0no ip addressencapsulation frame-relay...' (type 0)
> >
> >           bind :p1 <== 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostnam
> >
> >    e router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface E
> >
> >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysite inip inspect mysite
> >    outno keepalive!in
> >
> >    terface Serial0no ip addressencapsulation frame-relay...' (size
> 1399/1400/0, ptype 4, otype 1)
> >
> >           bind :p2 <== 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostnam
> >
> >    e router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface E
> >
> >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysiteinip inspect mysite
> >    outno keepalive!int
> >
> >    erface Serial0no ip addressencapsulation frame-relayn...' (type 0)
> >
> >           bind :p2 <== 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostnam
> >
> >    e router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface E
> >
> >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysiteinip inspect mysite
> >    outno keepalive!int
> >
> >    erface Serial0no ip addressencapsulation frame-relayn...' (size
> 1397/1398/0, ptype 4, otype 1)
> >
> >        dbd_st_execute INSERT (out0, lob0)...
> >
> >        !! ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> insert into a LONG column (DBD ERROR:
> >    OCIStmtExecute)' (e
> >
> >    rr#1)
> >
> >        <- execute= undef at test_insert_large.pl line 42
> >
> >    1   -> FETCH for DBD::Oracle::st (DBI::st=HASH(0x8149dcc)~INNER
> 'ParamValues') thr#8148ff0
> >
> >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> insert into a LONG column (DBD ERROR:
> >    OCIStmtExecute)' (e
> >
> >    rr#1)
> >
> >    1   <- FETCH= HASH(0x83487e0)2keys at test_insert_large.pl line 42
> >
> >        -> $DBI::errstr (&) FETCH from lasth=HASH
> >
> >        >> DBD::Oracle::st::errstr
> >
> >        <- $DBI::errstr= 'ORA-01461: can bind a LONG value only for
> insert into a LONG column (DBD ERROR:
> >    OCIStmtExecute)'
> >
> >        -- DBI::END
> >
> >        -> disconnect_all for DBD::Oracle::dr
> (DBI::dr=HASH(0x824771c)~0x82d419c) thr#8148ff0
> >
> >        <- disconnect_all= (not implemented) at DBI.pm line 673
> >
> >    Connect done
> >
> >    stmt: INSERT INTO test_table (item1,item2) VALUES (?, ?)
> >
> >    Size of vals is 2
> >
> >    val 1 size 1399, is: 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostna
> >
> >    me router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface
> >
> >    Ethernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysite inip inspect mysite
> >    outno keepalive!i
> >
> >    nterface Serial0no ip addressencapsulation frame-relayno fair-
> queue!interface Serial0.1 point-to-pointip
> >    address 10.10.11
> >
> >    .2 255.255.255.252ip access-group 102 inframe-relay interface-dlci
> 200 IETF!router eigrp 69network
> >    10.0.0.0no auto-summar
> >
> >    y!ip default-gateway 10.10.11.1no ip classlessip route 0.0.0.0
> 0.0.0.0 10.10.11.1access-list 101 permit
> >    tcp 10.10.10.0 0.
> >
> >    0.0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255 anyaccess-
> list 101 permit icmp 10.10.10.0
> >    0.0.0.255 anyaccess-
> >
> >    list 101 deny ip any anyaccess-list 102 permit eigrp any anyaccess-
> list 102 permit icmp any 10.10.10.0
> >    0.0.0.255 echo-rep
> >
> >    lyaccess-list 102 permit icmp any 10.10.10.0 0.0.0.255
> unreachableaccess-list 102 permit icmp any
> >    10.10.10.0 0.0.0.255 ad
> >
> >    ministratively-prohibitedaccess-list 102 permit icmp any 10.10.10.0
> 0.0.0.255 packet-too-bigaccess-list
> >    102 permit icmp a
> >
> >    ny 10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any
> 10.10.10.0 0.0.0.255
> >    time-exceededaccess-list 102 permit tcp
> >
> >    any host 10.10.10.1 eq smtpaccess-list 102 deny ip any any!line con
> 0line vty 0 4login!end'
> >
> >    val 2 size 1397, is: 'version 11.2no service password-
> encryptionservice udp-small-serversservice
> >    tcp-small-servers!hostna
> >
> >    me router1!!no ip domain-lookupip inspect name mysite ftpip inspect
> name mysite smtpip inspect name
> >    mysite tcp!interface
> >
> >    Ethernet0ip address 10.10.10.2 255.255.255.0ip access-group 101 inip
> inspect mysiteinip inspect mysite
> >    outno keepalive!in
> >
> >    terface Serial0no ip addressencapsulation frame-relayno fair-
> queue!interface Serial0.1 point-to-pointip
> >    address 10.10.11.
> >
> >    2 255.255.255.252ip access-group 102 inframe-relay interface-dlci 200
> IETF!router eigrp 69network
> >    10.0.0.0no auto-summary
> >
> >    !ip default-gateway 10.10.11.1no ip classlessip route 0.0.0.0 0.0.0.0
> 10.10.11.1access-list 101 permit
> >    tcp 10.10.10.0 0.0
> >
> >    .0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255 anyaccess-
> list 101 permiticmp 10.10.10.0
> >    0.0.0.255 anyaccess-li
> >
> >    st 101 deny ip any anyaccess-list 102 permit eigrp any anyaccess-list
> 102 permit icmp any 10.10.10.0
> >    0.0.0.255 echo-reply
> >
> >    access-list 102 permit icmp any 10.10.10.0 0.0.0.255
> unreachableaccess-list 102 permit icmp any
> >    10.10.10.0 0.0.0.255 admi
> >
> >    nistratively-prohibitedaccess-list 102 permit icmp any 10.10.10.0
> 0.0.0.255 packet-too-bigaccess-list
> >    102 permit icmp any
> >
> >     10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any 10.10.10.0
> 0.0.0.255 time-exceededaccess-list
> >    102 permit tcp an
> >
> >    y host 10.10.10.1 eq smtpaccess-list 102 deny ip any any!line con
> 0line vty 0 4login!end'
> >
> >    can't execute statement: error: ORA-01461: can bind a LONG value only
> for insert into a LONG column (DBD
> >    ERROR: OCIStmtEx
> >
> >    ecute)
> >
> >
> >
> >    !   -> DESTROY for DBD::Oracle::db (DBI::db=HASH(0x82d6580)~INNER)
> thr#8148ff0
> >
> >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> insert into a LONG column (DBD ERROR:
> >    OCIStmtExecute)' (e
> >
> >    rr#0)
> >
> >    !   <- DESTROY= undef during global destruction
> >
> >    !   -> DESTROY in DBD::_::common for DBD::Oracle::dr
> (DBI::dr=HASH(0x82d419c)~INNER) thr#8148ff0
> >
> >    !   <- DESTROY= undef during global destruction
> >
> >    !   -> DESTROY for DBD::Oracle::st (DBI::st=HASH(0x8149dcc)~INNER)
> thr#8148ff0
> >
> >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> insert into a LONG column (DBD ERROR:
> >    OCIStmtExecute)' (e
> >
> >    rr#1)
> >
> >    !   <- DESTROY= undef during global destruction
> >
> >
> >
> >    I will attach the test program.  Somehow it seems to think the
> datatype is LONG instead of VARCHAR.
> >
> >
> >
> >
> >
> >    Anyone with ideas?
> >
> >
> >
> >
> >
> >    Thanks,
> >
> >    Susan
> 


------=_NextPart_000_006A_01C4CC8F.60A4F6F0
Content-Type: application/octet-stream;
	name="test_insert_large.pl"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: attachment;
	filename="test_insert_large.pl"

#!/usr/local/bin/perl -w=0A=
=0A=
use DBI;=0A=
=0A=
our $dbh;=0A=
our $sth;=0A=
=0A=
$dbuser=3D"proj1";=0A=
$dbpasswd=3D"proj1";=0A=
=0A=
$dbserver=3D'oracledev';=0A=
$db_sid=3D'AL32UTF8';=0A=
=0A=
##=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D connect to database =
=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=3D=
=3D=3D=3D=3D=0A=
=0A=
$dbh=3D DBI->connect("dbi:Oracle:host=3D$dbserver;sid=3D$db_sid", =
$dbuser, $dbpasswd,=0A=
    {PrintError =3D> 0, AutoCommit =3D> 1}) or=0A=
 errexit( "Unable to connect to $dbserver: $DBI::errstr");=0A=
print "Connect done\n";=0A=
=0A=
#create table test_table (item1 varchar2(4000), item2 varchar2(4000));=0A=
=0A=
=0A=
my $statement=3D"INSERT INTO test_table (item1,item2) VALUES (?, ?)";=0A=
print "stmt: $statement\n";=0A=
=0A=
@vals=3D(=0A=
  'version 11.2no service password-encryptionservice =
udp-small-serversservice tcp-small-servers!hostname router1!!no ip =
domain-lookupip inspect name mysite ftpip inspect name mysite smtpip =
inspect name mysite tcp!interface Ethernet0ip address 10.10.10.2 =
255.255.255.0ip access-group 101 inip inspect mysite inip inspect mysite =
outno keepalive!interface Serial0no ip addressencapsulation =
frame-relayno fair-queue!interface Serial0.1 point-to-pointip address =
10.10.11.2 255.255.255.252ip access-group 102 inframe-relay =
interface-dlci 200 IETF!router eigrp 69network 10.0.0.0no =
auto-summary!ip default-gateway 10.10.11.1no ip classlessip route =
0.0.0.0 0.0.0.0 10.10.11.1access-list 101 permit tcp 10.10.10.0 =
0.0.0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255 =
anyaccess-list 101 permit icmp 10.10.10.0 0.0.0.255 anyaccess-list 101 =
deny ip any anyaccess-list 102 permit eigrp any anyaccess-list 102 =
permit icmp any 10.10.10.0 0.0.0.255 echo-replyaccess-list 102 permit =
icmp any 10.10.10.0 0.0.0.255 unreachableaccess-list 102 permit icmp any =
10.10.10.0 0.0.0.255 administratively-prohibitedaccess-list 102 permit =
icmp any 10.10.10.0 0.0.0.255 packet-too-bigaccess-list 102 permit icmp =
any 10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any 10.10.10.0 =
0.0.0.255 time-exceededaccess-list 102 permit tcp any host 10.10.10.1 eq =
smtpaccess-list 102 deny ip any any!line con 0line vty 0 4login!end',=0A=
 'version 11.2no service password-encryptionservice =
udp-small-serversservice tcp-small-servers!hostname router1!!no ip =
domain-lookupip inspect name mysite ftpip inspect name mysite smtpip =
inspect name mysite tcp!interface Ethernet0ip address 10.10.10.2 =
255.255.255.0ip access-group 101 inip inspect mysiteinip inspect mysite =
outno keepalive!interface Serial0no ip addressencapsulation =
frame-relayno fair-queue!interface Serial0.1 point-to-pointip address =
10.10.11.2 255.255.255.252ip access-group 102 inframe-relay =
interface-dlci 200 IETF!router eigrp 69network 10.0.0.0no =
auto-summary!ip default-gateway 10.10.11.1no ip classlessip route =
0.0.0.0 0.0.0.0 10.10.11.1access-list 101 permit tcp 10.10.10.0 =
0.0.0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255 =
anyaccess-list 101 permiticmp 10.10.10.0 0.0.0.255 anyaccess-list 101 =
deny ip any anyaccess-list 102 permit eigrp any anyaccess-list 102 =
permit icmp any 10.10.10.0 0.0.0.255 echo-replyaccess-list 102 permit =
icmp any 10.10.10.0 0.0.0.255 unreachableaccess-list 102 permit icmp any =
10.10.10.0 0.0.0.255 administratively-prohibitedaccess-list 102 permit =
icmp any 10.10.10.0 0.0.0.255 packet-too-bigaccess-list 102 permit icmp =
any 10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any 10.10.10.0 =
0.0.0.255 time-exceededaccess-list 102 permit tcp any host 10.10.10.1 eq =
smtpaccess-list 102 deny ip any any!line con 0line vty 0 4login!end',=0A=
);=0A=
=0A=
print "Size of vals is ",scalar @vals,"\n";=0A=
my $z=3D0;=0A=
foreach my $x (@vals) {=0A=
  my $len=3Dlength($x);=0A=
  print "val ",++$z, " size $len, is: '$x'\n";=0A=
}=0A=
=0A=
DBI->trace(2);=0A=
  $sth=3D$dbh->prepare($statement) ||=0A=
    errexit("bad prepare for stmt $statement, error: $DBI::errstr");=0A=
  my $rc=3D$sth->execute(@vals) ||=0A=
    errexit("can't execute statement: error: $DBI::errstr\n");=0A=
=0A=
print "Done\n";=0A=
exit;=0A=
=0A=
=0A=
sub errexit {=0A=
  my (@msg)=3D@_;=0A=
  print @msg,"\n";=0A=
  exit 1;=0A=
}=0A=
=0A=
=0A=
=0A=

------=_NextPart_000_006A_01C4CC8F.60A4F6F0--


From SRS0=YmHr=OD=systransoft.com=cassidy@bounce2.pobox.com  Thu Nov 18 00:15:21 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id iAI0FC8G049539
	for <timbo@localhost>; Thu, 18 Nov 2004 00:15:21 GMT
	(envelope-from SRS0=YmHr=OD=systransoft.com=cassidy@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 18 Nov 2004 00:15:21 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CUVdd-0002Nv-CF;
	Wed, 17 Nov 2004 19:38:45 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CUVdd-0002Nv-CF
	for pobox@data-plan.com; Wed, 17 Nov 2004 19:38:45 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1CUVdc-0005lu-Rs
	for pobox@data-plan.com; Wed, 17 Nov 2004 19:38:45 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 4A256ADD6F;
	Wed, 17 Nov 2004 14:38:44 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from boggle (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 3D82CADD64
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 17 Nov 2004 14:38:44 -0500 (EST)
Received-SPF: none (boggle.pobox.com: domain of cassidy@systransoft.com does not designate permitted sender hosts)
X-SPF-Guess: pass (seems reasonable for cassidy@systransoft.com to mail through 66.185.164.3)
Received: from mailhost.systransoft.com (mailhost.systransoft.com [66.185.164.3])
	by boggle.pobox.com (Postfix) with ESMTP id B23D4ADCF6
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 14:38:15 -0500 (EST)
Received: from localhost (localhost [127.0.0.1])
	by mailhost.systransoft.com (Postfix) with ESMTP id 0C9DF24435B
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 11:38:14 -0800 (PST)
Received: from mailhost.systransoft.com ([127.0.0.1])
 by localhost (mailhost.systransoft.com [127.0.0.1]) (amavisd-new, port 10024)
 with ESMTP id 18475-01 for <Tim.Bunce@pobox.com>;
 Wed, 17 Nov 2004 11:38:13 -0800 (PST)
Received: from hapax (hapax [192.168.2.186])
	by mailhost.systransoft.com (Postfix) with ESMTP id ACF0424406F
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 11:38:13 -0800 (PST)
From: "Susan Cassidy" <cassidy@systransoft.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: FW: DBD::Oracle and strange problem with Oracle error 'ORA-01461: can bind a LONG value only for insert into a LONG column' when data not LONG
Date: Wed, 17 Nov 2004 11:36:14 -0800
Organization: SYSTRAN Software, Inc.
MIME-Version: 1.0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit
X-Mailer: Microsoft Office Outlook, Build 11.0.5510
In-Reply-To: <20041117192902.GA31595@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2800.1441
Thread-Index: AcTM27+9yfJDVs3WQIWAKc6DR3EgdQAAKfgw
Message-Id: <20041117193813.ACF0424406F@mailhost.systransoft.com>
X-Virus-Scanned: by amavisd-new at systransoft.com
Status: RO
X-Status: A
Content-Length: 14671
Lines: 489

NLS_LANG=.UTF8
ORA_NLS33=/home/oracle/product/9.2.0/ocommon/nls/admin/data
ORA_NLS33=/home/oracle/product/9.2.0/ocommon/nls/admin/data
ORACLE_HOME=/home/oracle/product/9.2.0
ORACLE_SID=AL32UTF8
ORACLE_BASE=/home/oracle

NLS_NCHAR is not set, because we are not using any NVARCHAR data item, and
haven't needed it.

Susan

> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> Sent: Wednesday, November 17, 2004 11:29 AM
> To: Susan Cassidy
> Cc: 'Tim Bunce'
> Subject: Re: FW: DBD::Oracle and strange problem with Oracle error 'ORA-
> 01461: can bind a LONG value only for insert into a LONG column' when data
> not LONG
> 
> Thanks. What are your client side NLS_LANG and NLS_NCHAR settings?
> 
> Tim.
> 
> On Wed, Nov 17, 2004 at 10:22:44AM -0800, Susan Cassidy wrote:
> > I did - it is attached to the posting.  However, I will attach it again
> > here.
> >
> > Thanks,
> > Susan
> >
> > > -----Original Message-----
> > > From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> > > Sent: Wednesday, November 17, 2004 9:33 AM
> > > To: Susan Cassidy
> > > Cc: dbi-users@perl.org
> > > Subject: Re: FW: DBD::Oracle and strange problem with Oracle error
> 'ORA-
> > > 01461: can bind a LONG value only for insert into a LONG column' when
> data
> > > not LONG
> > >
> > > If you can post a small self-contained example that demonstrates
> > > the problem then I'll take a look.
> > >
> > > Tim.
> > >
> > > On Wed, Nov 17, 2004 at 09:15:52AM -0800, Susan Cassidy wrote:
> > > >    I never got any response to my question about this problem.  I
> > > thought I'd try again.
> > > >
> > > >
> > > >
> > > >    This is DBD::Oracle 1.16, DBI 1.45, Oracle 9i (9.2), Linux, Perl
> > > 5.8.5.
> > > >
> > > >
> > > >
> > > >    Thanks,
> > > >
> > > >    Susan
> > > >
> > > >
> > > >
> > > >    -----------------------------------------------------------------
> ----
> > > -----------------------------------
> > > >
> > > >    From: Susan Cassidy [mailto:cassidy@systransoft.com]
> > > >    Sent: Friday, November 05, 2004 10:23 AM
> > > >    To: 'dbi-users@perl.org'
> > > >    Subject: DBD::Oracle and strange problem with Oracle error 'ORA-
> > > 01461: can bind a LONG value only for
> > > >    insert into a LONG column' when data not LONG
> > > >
> > > >
> > > >
> > > >    I had an application that was processing a bunch of xml and
> inserting
> > > into a table with a bunch of
> > > >    VARCHAR2(4000) columns.
> > > >
> > > >
> > > >
> > > >    A couple of the entries I was processing caused the 'ORA-01461:
> can
> > > bind a LONG value only for insert
> > > >    into a LONG column' error.
> > > >
> > > >
> > > >
> > > >    I put checks in for the length of the data, and nothing
> approached
> > > 4000 bytes in length.
> > > >
> > > >
> > > >
> > > >    I tracked down some of the entries causing problems, and on
> certain
> > > specific data, if 2 columns
> > > >    containing specific data are inserted together, I get this error.
> If
> > > only one of the 2 is inserted, I
> > > >    do not get the error, regardless of which one of the two I
> insert.
> > > >
> > > >
> > > >
> > > >    The lengths of the pieces of data are 1399 and 1397 characters.
> > > >
> > > >
> > > >
> > > >    The data is somewhat odd-looking (we suspect some odd data is in
> this
> > > file), but there is no reason for
> > > >    the error message to appear.
> > > >
> > > >
> > > >
> > > >    Trace shows nothing helpful - it thinks the data is the right
> length.
> > > >
> > > >
> > > >
> > > >    We've successfully inserted thousands of other, similar entries
> with
> > > no trouble.
> > > >
> > > >
> > > >
> > > >    The basics are:
> > > >
> > > >    #create table test_table (item1 varchar2(4000), item2
> > > varchar2(4000));
> > > >
> > > >
> > > >
> > > >    my $statement="INSERT INTO test_table (item1,item2) VALUES (?,
> ?)";
> > > >
> > > >
> > > >
> > > >      $sth=$dbh->prepare($statement) ||
> > > >
> > > >        errexit("bad prepare for stmt $statement, error:
> $DBI::errstr");
> > > >
> > > >      my $rc=$sth->execute(@vals) ||
> > > >
> > > >        errexit("can't execute statement: error: $DBI::errstr\n");
> > > >
> > > >
> > > >
> > > >    Trace shows:
> > > >
> > > >
> > > >
> > > >        DBI 1.45-ithread default trace level set to 0x0/2 (pid 6230)
> > > >
> > > >        -> prepare for DBD::Oracle::db
> (DBI::db=HASH(0x82d4178)~0x82d6580
> > > 'INSERT INTO test_table
> > > >    (item1,item2) VALUES (?, ?)
> > > >
> > > >    ') thr#8148ff0
> > > >
> > > >        dbd_preparse scanned 2 distinct placeholders
> > > >
> > > >        <- prepare= DBI::st=HASH(0x82d6640) at test_insert_large.pl
> line
> > > 40
> > > >
> > > >        -> execute for DBD::Oracle::st
> (DBI::st=HASH(0x82d6640)~0x8149dcc
> > > 'version 11.2no service
> > > >    password-encryptionservice
> > > >
> > > >    udp-small-serversservice tcp-small-servers!hostname router1!!no
> ip
> > > domain-lookupip inspect name mysite
> > > >    ftpip inspect name
> > > >
> > > >     mysite smtpip inspect name mysite tcp!interface Ethernet0ip
> address
> > > 10.10.10.2 255.255.255.0ip
> > > >    access-group 101 inip ins
> > > >
> > > >    pect mysite inip inspect mysite outno keepalive!interface
> Serial0no
> > > ip addressencapsulation
> > > >    frame-relay...' 'version 11.2
> > > >
> > > >    no service password-encryptionservice udp-small-serversservice
> tcp-
> > > small-servers!hostname router1!!no ip
> > > >    domain-lookupip
> > > >
> > > >    inspect name mysite ftpip inspect name mysite smtpip inspect name
> > > mysite tcp!interface Ethernet0ip
> > > >    address 10.10.10.2 255
> > > >
> > > >    .255.255.0ip access-group 101 inip inspect mysiteinip inspect
> mysite
> > > outno keepalive!interface Serial0no
> > > >    ip addressencaps
> > > >
> > > >    ulation frame-relayn...') thr#8148ff0
> > > >
> > > >           bind :p1 <== 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostnam
> > > >
> > > >    e router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface E
> > > >
> > > >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysite inip inspect mysite
> > > >    outno keepalive!in
> > > >
> > > >    terface Serial0no ip addressencapsulation frame-relay...' (type
> 0)
> > > >
> > > >           bind :p1 <== 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostnam
> > > >
> > > >    e router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface E
> > > >
> > > >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysite inip inspect mysite
> > > >    outno keepalive!in
> > > >
> > > >    terface Serial0no ip addressencapsulation frame-relay...' (size
> > > 1399/1400/0, ptype 4, otype 1)
> > > >
> > > >           bind :p2 <== 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostnam
> > > >
> > > >    e router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface E
> > > >
> > > >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysiteinip inspect mysite
> > > >    outno keepalive!int
> > > >
> > > >    erface Serial0no ip addressencapsulation frame-relayn...' (type
> 0)
> > > >
> > > >           bind :p2 <== 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostnam
> > > >
> > > >    e router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface E
> > > >
> > > >    thernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysiteinip inspect mysite
> > > >    outno keepalive!int
> > > >
> > > >    erface Serial0no ip addressencapsulation frame-relayn...' (size
> > > 1397/1398/0, ptype 4, otype 1)
> > > >
> > > >        dbd_st_execute INSERT (out0, lob0)...
> > > >
> > > >        !! ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> > > insert into a LONG column (DBD ERROR:
> > > >    OCIStmtExecute)' (e
> > > >
> > > >    rr#1)
> > > >
> > > >        <- execute= undef at test_insert_large.pl line 42
> > > >
> > > >    1   -> FETCH for DBD::Oracle::st (DBI::st=HASH(0x8149dcc)~INNER
> > > 'ParamValues') thr#8148ff0
> > > >
> > > >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> > > insert into a LONG column (DBD ERROR:
> > > >    OCIStmtExecute)' (e
> > > >
> > > >    rr#1)
> > > >
> > > >    1   <- FETCH= HASH(0x83487e0)2keys at test_insert_large.pl line
> 42
> > > >
> > > >        -> $DBI::errstr (&) FETCH from lasth=HASH
> > > >
> > > >        >> DBD::Oracle::st::errstr
> > > >
> > > >        <- $DBI::errstr= 'ORA-01461: can bind a LONG value only for
> > > insert into a LONG column (DBD ERROR:
> > > >    OCIStmtExecute)'
> > > >
> > > >        -- DBI::END
> > > >
> > > >        -> disconnect_all for DBD::Oracle::dr
> > > (DBI::dr=HASH(0x824771c)~0x82d419c) thr#8148ff0
> > > >
> > > >        <- disconnect_all= (not implemented) at DBI.pm line 673
> > > >
> > > >    Connect done
> > > >
> > > >    stmt: INSERT INTO test_table (item1,item2) VALUES (?, ?)
> > > >
> > > >    Size of vals is 2
> > > >
> > > >    val 1 size 1399, is: 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostna
> > > >
> > > >    me router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface
> > > >
> > > >    Ethernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysite inip inspect mysite
> > > >    outno keepalive!i
> > > >
> > > >    nterface Serial0no ip addressencapsulation frame-relayno fair-
> > > queue!interface Serial0.1 point-to-pointip
> > > >    address 10.10.11
> > > >
> > > >    .2 255.255.255.252ip access-group 102 inframe-relay interface-
> dlci
> > > 200 IETF!router eigrp 69network
> > > >    10.0.0.0no auto-summar
> > > >
> > > >    y!ip default-gateway 10.10.11.1no ip classlessip route 0.0.0.0
> > > 0.0.0.0 10.10.11.1access-list 101 permit
> > > >    tcp 10.10.10.0 0.
> > > >
> > > >    0.0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255
> anyaccess-
> > > list 101 permit icmp 10.10.10.0
> > > >    0.0.0.255 anyaccess-
> > > >
> > > >    list 101 deny ip any anyaccess-list 102 permit eigrp any
> anyaccess-
> > > list 102 permit icmp any 10.10.10.0
> > > >    0.0.0.255 echo-rep
> > > >
> > > >    lyaccess-list 102 permit icmp any 10.10.10.0 0.0.0.255
> > > unreachableaccess-list 102 permit icmp any
> > > >    10.10.10.0 0.0.0.255 ad
> > > >
> > > >    ministratively-prohibitedaccess-list 102 permit icmp any
> 10.10.10.0
> > > 0.0.0.255 packet-too-bigaccess-list
> > > >    102 permit icmp a
> > > >
> > > >    ny 10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any
> > > 10.10.10.0 0.0.0.255
> > > >    time-exceededaccess-list 102 permit tcp
> > > >
> > > >    any host 10.10.10.1 eq smtpaccess-list 102 deny ip any any!line
> con
> > > 0line vty 0 4login!end'
> > > >
> > > >    val 2 size 1397, is: 'version 11.2no service password-
> > > encryptionservice udp-small-serversservice
> > > >    tcp-small-servers!hostna
> > > >
> > > >    me router1!!no ip domain-lookupip inspect name mysite ftpip
> inspect
> > > name mysite smtpip inspect name
> > > >    mysite tcp!interface
> > > >
> > > >    Ethernet0ip address 10.10.10.2 255.255.255.0ip access-group 101
> inip
> > > inspect mysiteinip inspect mysite
> > > >    outno keepalive!in
> > > >
> > > >    terface Serial0no ip addressencapsulation frame-relayno fair-
> > > queue!interface Serial0.1 point-to-pointip
> > > >    address 10.10.11.
> > > >
> > > >    2 255.255.255.252ip access-group 102 inframe-relay interface-dlci
> 200
> > > IETF!router eigrp 69network
> > > >    10.0.0.0no auto-summary
> > > >
> > > >    !ip default-gateway 10.10.11.1no ip classlessip route 0.0.0.0
> 0.0.0.0
> > > 10.10.11.1access-list 101 permit
> > > >    tcp 10.10.10.0 0.0
> > > >
> > > >    .0.255 anyaccess-list 101 permit udp 10.10.10.0 0.0.0.255
> anyaccess-
> > > list 101 permiticmp 10.10.10.0
> > > >    0.0.0.255 anyaccess-li
> > > >
> > > >    st 101 deny ip any anyaccess-list 102 permit eigrp any anyaccess-
> list
> > > 102 permit icmp any 10.10.10.0
> > > >    0.0.0.255 echo-reply
> > > >
> > > >    access-list 102 permit icmp any 10.10.10.0 0.0.0.255
> > > unreachableaccess-list 102 permit icmp any
> > > >    10.10.10.0 0.0.0.255 admi
> > > >
> > > >    nistratively-prohibitedaccess-list 102 permit icmp any 10.10.10.0
> > > 0.0.0.255 packet-too-bigaccess-list
> > > >    102 permit icmp any
> > > >
> > > >     10.10.10.0 0.0.0.255 echoaccess-list 102 permit icmp any
> 10.10.10.0
> > > 0.0.0.255 time-exceededaccess-list
> > > >    102 permit tcp an
> > > >
> > > >    y host 10.10.10.1 eq smtpaccess-list 102 deny ip any any!line con
> > > 0line vty 0 4login!end'
> > > >
> > > >    can't execute statement: error: ORA-01461: can bind a LONG value
> only
> > > for insert into a LONG column (DBD
> > > >    ERROR: OCIStmtEx
> > > >
> > > >    ecute)
> > > >
> > > >
> > > >
> > > >    !   -> DESTROY for DBD::Oracle::db
> (DBI::db=HASH(0x82d6580)~INNER)
> > > thr#8148ff0
> > > >
> > > >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> > > insert into a LONG column (DBD ERROR:
> > > >    OCIStmtExecute)' (e
> > > >
> > > >    rr#0)
> > > >
> > > >    !   <- DESTROY= undef during global destruction
> > > >
> > > >    !   -> DESTROY in DBD::_::common for DBD::Oracle::dr
> > > (DBI::dr=HASH(0x82d419c)~INNER) thr#8148ff0
> > > >
> > > >    !   <- DESTROY= undef during global destruction
> > > >
> > > >    !   -> DESTROY for DBD::Oracle::st
> (DBI::st=HASH(0x8149dcc)~INNER)
> > > thr#8148ff0
> > > >
> > > >           ERROR: '1461' 'ORA-01461: can bind a LONG value only for
> > > insert into a LONG column (DBD ERROR:
> > > >    OCIStmtExecute)' (e
> > > >
> > > >    rr#1)
> > > >
> > > >    !   <- DESTROY= undef during global destruction
> > > >
> > > >
> > > >
> > > >    I will attach the test program.  Somehow it seems to think the
> > > datatype is LONG instead of VARCHAR.
> > > >
> > > >
> > > >
> > > >
> > > >
> > > >    Anyone with ideas?
> > > >
> > > >
> > > >
> > > >
> > > >
> > > >    Thanks,
> > > >
> > > >    Susan
> > >
> >
> 



From SRS0=xs68=OE=systransoft.com=cassidy@bounce2.pobox.com  Thu Nov 18 07:11:03 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id iAI7Ar8G057950
	for <timbo@localhost>; Thu, 18 Nov 2004 07:11:03 GMT
	(envelope-from SRS0=xs68=OE=systransoft.com=cassidy@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 18 Nov 2004 07:11:03 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CUaCR-0002mS-7P;
	Thu, 18 Nov 2004 00:30:59 +0000
Received: from [194.217.242.72] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CUaCR-0002mS-7P
	for pobox@data-plan.com; Thu, 18 Nov 2004 00:30:59 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1CUaCQ-0004JQ-R5
	for pobox@data-plan.com; Thu, 18 Nov 2004 00:30:59 +0000
Received: from integer.pobox.com (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 17ACAA3F35;
	Wed, 17 Nov 2004 19:30:58 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from integer (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 04F8DA3EAC
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 17 Nov 2004 19:30:58 -0500 (EST)
Received-SPF: none (integer.pobox.com: domain of cassidy@systransoft.com does not designate permitted sender hosts)
X-SPF-Guess: pass (seems reasonable for cassidy@systransoft.com to mail through 66.185.164.3)
Received: from mailhost.systransoft.com (mailhost.systransoft.com [66.185.164.3])
	by integer.pobox.com (Postfix) with ESMTP id A9FC6A3F4D
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 19:30:43 -0500 (EST)
Received: from localhost (localhost [127.0.0.1])
	by mailhost.systransoft.com (Postfix) with ESMTP id DEA102441A9
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 16:30:41 -0800 (PST)
Received: from mailhost.systransoft.com ([127.0.0.1])
 by localhost (mailhost.systransoft.com [127.0.0.1]) (amavisd-new, port 10024)
 with ESMTP id 22204-10 for <Tim.Bunce@pobox.com>;
 Wed, 17 Nov 2004 16:30:41 -0800 (PST)
Received: from hapax (hapax [192.168.2.186])
	by mailhost.systransoft.com (Postfix) with ESMTP id 7AD52244370
	for <Tim.Bunce@pobox.com>; Wed, 17 Nov 2004 16:30:40 -0800 (PST)
From: "Susan Cassidy" <cassidy@systransoft.com>
To: "'Tim Bunce'" <Tim.Bunce@pobox.com>
Subject: RE: FW: DBD::Oracle and strange problem with Oracle error 'ORA-01461: can bind a LONG value only for insert into a LONG column' when data not LONG
Date: Wed, 17 Nov 2004 16:28:41 -0800
Organization: SYSTRAN Software, Inc.
MIME-Version: 1.0
Content-Type: text/plain;
	charset="us-ascii"
Content-Transfer-Encoding: 7bit
X-Mailer: Microsoft Office Outlook, Build 11.0.5510
In-Reply-To: <20041118001712.GB49519@dansat.data-plan.com>
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2800.1441
Thread-Index: AcTNA/o7HZXghXaJRbyz8M5kVQMQmwAAUBjg
Message-Id: <20041118003040.7AD52244370@mailhost.systransoft.com>
X-Virus-Scanned: by amavisd-new at systransoft.com
Status: RO
Content-Length: 1789
Lines: 63

Hi,

I set NLS_LANG to .US7ASCII, ran it again, and I get the same error.

Of course, I could not use that in production.

The really strange part, to me, was that if I just insert one of the 2
problematic columns, it worked, but both together failed.

Thanks,
Susan

> -----Original Message-----
> From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> Sent: Wednesday, November 17, 2004 4:17 PM
> To: Susan Cassidy
> Cc: 'Tim Bunce'
> Subject: Re: FW: DBD::Oracle and strange problem with Oracle error 'ORA-
> 01461: can bind a LONG value only for insert into a LONG column' when data
> not LONG
> 
> And does the problem go away if NLS_LANG is set to a non-unicode charset?
> 
> Tim.
> 
> On Wed, Nov 17, 2004 at 11:36:14AM -0800, Susan Cassidy wrote:
> > NLS_LANG=.UTF8
> > ORA_NLS33=/home/oracle/product/9.2.0/ocommon/nls/admin/data
> > ORA_NLS33=/home/oracle/product/9.2.0/ocommon/nls/admin/data
> > ORACLE_HOME=/home/oracle/product/9.2.0
> > ORACLE_SID=AL32UTF8
> > ORACLE_BASE=/home/oracle
> >
> > NLS_NCHAR is not set, because we are not using any NVARCHAR data item,
> and
> > haven't needed it.
> >
> > Susan
> >
> > > -----Original Message-----
> > > From: Tim Bunce [mailto:Tim.Bunce@pobox.com]
> > > Sent: Wednesday, November 17, 2004 11:29 AM
> > > To: Susan Cassidy
> > > Cc: 'Tim Bunce'
> > > Subject: Re: FW: DBD::Oracle and strange problem with Oracle error
> 'ORA-
> > > 01461: can bind a LONG value only for insert into a LONG column' when
> data
> > > not LONG
> > >
> > > Thanks. What are your client side NLS_LANG and NLS_NCHAR settings?
> > >
> > > Tim.
> > >
> > > On Wed, Nov 17, 2004 at 10:22:44AM -0800, Susan Cassidy wrote:
> > > > I did - it is attached to the posting.  However, I will attach it
> again
> > > > here.
> > > >
> > > > Thanks,
> > > > Susan
> > > >


