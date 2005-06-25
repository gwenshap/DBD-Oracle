From SRS0=sbeK=NO=perl.org=dbi-dev-return-3749-Tim.Bunce=pobox.com@bounce2.pobox.com  Wed Oct 27 15:22:22 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i9RELAAO018624
	for <timbo@localhost>; Wed, 27 Oct 2004 15:22:22 +0100 (BST)
	(envelope-from SRS0=sbeK=NO=perl.org=dbi-dev-return-3749-Tim.Bunce=pobox.com@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 27 Oct 2004 15:22:22 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CMiQ8-0000Eo-FG;
	Wed, 27 Oct 2004 07:40:36 +0000
Received: from [194.217.242.72] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CMiQ8-0000Eo-FG
	for pobox@data-plan.com; Wed, 27 Oct 2004 07:40:36 +0000
Received: from [207.8.226.3] (helo=icicle.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1CMiQ8-0006dS-9n
	for pobox@data-plan.com; Wed, 27 Oct 2004 07:40:36 +0000
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id B3BB911C325;
	Wed, 27 Oct 2004 03:40:35 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from icicle (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 9947911C2CE
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 27 Oct 2004 03:40:35 -0400 (EDT)
Received-SPF: pass (icicle.pobox.com: domain of dbi-dev-return-3749-Tim.Bunce=pobox.com@perl.org designates 63.251.223.186 as permitted sender)
X-SPF-Guess: pass (seems reasonable for dbi-dev-return-3749-Tim.Bunce=pobox.com@perl.org to mail through 63.251.223.186)
X-Pobox-Antispam: dnsbl/blackholes.five-ten-sg.com returned DENY: for 63.251.223.186(x6.develooper.com)
Received: from lists.develooper.com (x6.develooper.com [63.251.223.186])
	by icicle.pobox.com (Postfix) with SMTP id 5033611C34F
	for <Tim.Bunce@pobox.com>; Wed, 27 Oct 2004 03:39:46 -0400 (EDT)
Received: (qmail 12004 invoked by uid 514); 27 Oct 2004 07:39:43 -0000
Mailing-List: contact dbi-dev-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-dev@perl.org>
List-Help: <mailto:dbi-dev-help@perl.org>
List-Unsubscribe: <mailto:dbi-dev-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-dev-subscribe@perl.org>
Delivered-To: mailing list dbi-dev@perl.org
Received: (qmail 11995 invoked from network); 27 Oct 2004 07:39:43 -0000
Received: from x1.develooper.com (63.251.223.170)
  by lists.develooper.com with SMTP; 27 Oct 2004 07:39:43 -0000
Received: (qmail 13565 invoked by uid 225); 27 Oct 2004 07:39:43 -0000
Delivered-To: dbi-dev@perl.org
Received: (qmail 13560 invoked by alias); 27 Oct 2004 07:39:42 -0000
X-Spam-Status: No, hits=-3.7 required=8.0
	tests=BAYES_00,LARGE_HEX
X-Spam-Check-By: la.mx.develooper.com
Received: from smtp-vbr15.xs4all.nl (HELO smtp-vbr15.xs4all.nl) (194.109.24.35)
  by la.mx.develooper.com (qpsmtpd/0.27.1) with ESMTP; Wed, 27 Oct 2004 00:39:40 -0700
Received: from [127.0.0.1] (procura.xs4all.nl [213.84.163.145])
	by smtp-vbr15.xs4all.nl (8.12.11/8.12.11) with ESMTP id i9R7dWHI013040;
	Wed, 27 Oct 2004 09:39:34 +0200 (CEST)
	(envelope-from h.m.brand@hccnet.nl)
Date: Wed, 27 Oct 2004 09:39:33 +0200
From: "H.Merijn Brand" <h.m.brand@hccnet.nl>
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: ANNOUNCE: DBD::Oracle 1.16
Cc: DBI developers <dbi-dev@perl.org>
In-Reply-To: <20041022213625.GA22377@dansat.data-plan.com>
References: <20041022213625.GA22377@dansat.data-plan.com>
Message-Id: <20041027093516.D001.H.M.BRAND@hccnet.nl>
MIME-Version: 1.0
Content-Type: text/plain; charset="US-ASCII"
X-Mailer: Becky! ver. 2.11.02 [en]
X-Virus-Scanned: by XS4ALL Virus Scanner
X-Virus-Checked: Checked
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id i9RELAAO018624
Status: RO
X-Status: A
Content-Length: 7175
Lines: 134

On Fri 22 Oct 2004 23:36, Tim Bunce <Tim.Bunce@pobox.com> wrote:
>   file: $CPAN/authors/id/T/TI/TIMB/DBD-Oracle-1.16.tar.gz
>   size: 235224 bytes
>    md5: 9711550ed0ebfc743920a6a357ed717c

I know you can't blame the test for not being able to create a table for the
reason this failure shows, but there might be a more user-friendly way to fail ...

I'll report back when the DBA has fixed the tablespace

HP-UX 11.11/64 (11i) + Oracle-9.2.0/64 + perl-5.8.5-dor/64

PERL_DL_NONLAZY=1 /pro/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0,
'blib/lib', 'blib/arch')" t/*.t
t/01base................ok
t/10general.............ok
t/15nls.................ok
t/20select..............ok
t/21nchar............... Database and client versions and character sets:
Database 9.2.0.1.0 CHAR set is US7ASCII (Non-Unicode), NCHAR set is AL16UTF16 (
nicode)
Client 9.2.0.1 NLS_LANG is '<unset>', NLS_NCHAR is '<unset>'
t/21nchar...............ok
t/22nchar_al32utf8......ok
t/22nchar_utf8..........ok
t/23wide_db.............skipped
        all skipped: Database character set is not Unicode
t/23wide_db_8bit........skipped
        all skipped: Database character set is not Unicode
t/23wide_db_al32utf8....skipped
        all skipped: Database character set is not Unicode
t/24implicit_utf8.......ok
t/25plsql...............ok
t/30long................ok 188/470DBD::Oracle::db do failed: ORA-03237: Initial
Extent of specified size cannot be allocated in tablespace (PROBEV) (DBD ERROR:
OCIStmtExecute) [for Statement "create table dbd_ora__drop_me ( idx integer, ln
 NCLOB,  dt date )"] at t/nchar_test_lib.pl line 356.
t/30long................ok 189/470DBD::Oracle::st execute failed: ORA-00942: ta
le or view does not exist (DBD ERROR: error possibly near <*> indicator at char
12 in 'insert into <*>dbd_ora__drop_me values (:p1, :p2, SYSDATE)') [for Statem
nt "insert into dbd_ora__drop_me values (?, ?, SYSDATE)" with ParamValues: :p1=
0, :p2='0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0
x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0
x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0
x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0
x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0.x.X0
x.X...'] at t/30long.t line 153.
#     Failed test (t/30long.t at line 153)
t/30long................NOK 190DBD::Oracle::st execute failed: ORA-00942: table
or view does not exist (DBD ERROR: error possibly near <*> indicator at char 12
in 'insert into <*>dbd_ora__drop_me values (:p1, :p2, SYSDATE)') [for Statement
"insert into dbd_ora__drop_me values (?, ?, SYSDATE)" with ParamValues: :p1=41,
:p2='12345678901234567890123456789012345678901234567890123456789012345678901234
6789012345678901234567890123456789012345678901234567890123456789012345678901234
6789012345678901234567890123456789012345678901234567890123456789012345678901234
6789012345678901234567890123456789012345678901234567890123456789012345678901234
6789012345678901234567890123456789012345678901234567890123456789012345678901234
...'] at t/30long.t line 154.
#     Failed test (t/30long.t at line 154)
t/30long................NOK 191DBD::Oracle::st execute failed: ORA-00942: table
or view does not exist (DBD ERROR: error possibly near <*> indicator at char 12
in 'insert into <*>dbd_ora__drop_me values (:p1, :p2, SYSDATE)') [for Statement
"insert into dbd_ora__drop_me values (?, ?, SYSDATE)" with ParamValues: :p1=42,
:p2='2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcd
fabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcd
fabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcd
fabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcd
fabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcdefabcd2bcd
...'] at t/30long.t line 155.
t/30long................NOK 192#     Failed test (t/30long.t at line 155)
DBD::Oracle::st execute failed: ORA-00942: table or view does not exist (DBD ER
OR: error possibly near <*> indicator at char 12 in 'insert into <*>dbd_ora__dr
p_me values (:p1, :p2, SYSDATE)') [for Statement "insert into dbd_ora__drop_me
alues (?, ?, SYSDATE)" with ParamValues: :p1=43, :p2=undef] at t/30long.t line
56.
#     Failed test (t/30long.t at line 156)
t/30long................NOK 193DBD::Oracle::db prepare failed: ORA-00942: table
or view does not exist (DBD ERROR: error possibly near <*> indicator at char 14
in 'select * from <*>dbd_ora__drop_me order by idx') [for Statement "select * f
om dbd_ora__drop_me order by idx"] at t/30long.t line 170.
#     Failed test (t/30long.t at line 170)
Can't call method "trace" on an undefined value at t/30long.t line 171.
t/30long................NOK 194# Looks like you planned 470 tests but only ran
94.
# Looks like your test died just after 194.
t/30long................dubious
        Test returned status 255 (wstat 65280, 0xff00)
DIED. FAILED tests 190-470
        Failed 281/470 tests, 40.21% okay (less 122 skipped tests: 67 okay, 14.
6%)
t/31lob.................DBD::Oracle::db do failed: ORA-03237: Initial Extent of
specified size cannot be allocated in tablespace (PROBEV) (DBD ERROR: OCIStmtEx
cute) [for Statement "
        CREATE TABLE dbd_ora__drop_me (
            id INTEGER NOT NULL,
            data BLOB
        )
    "] at t/31lob.t line 21.
DBD::Oracle::db do failed: ORA-00942: table or view does not exist (DBD ERROR:
rror possibly near <*> indicator at char 12 in 'INSERT INTO <*>dbd_ora__drop_me
(id,data) VALUES (1, EMPTY_BLOB())') [for Statement "INSERT INTO dbd_ora__drop_
e (id,data) VALUES (1, EMPTY_BLOB())"] at t/31lob.t line 31.
DBD::Oracle::db prepare failed: ORA-00942: table or view does not exist (DBD ER
OR: error possibly near <*> indicator at char 17 in 'SELECT data FROM <*>dbd_or
__drop_me WHERE id = :p1') [for Statement "SELECT data FROM dbd_ora__drop_me WH
RE id = ?"] at t/31lob.t line 34.
Can't call method "bind_param" on an undefined value at t/31lob.t line 36.
# Looks like your test died before it could output anything.
t/31lob.................dubious
        Test returned status 255 (wstat 65280, 0xff00)
DIED. FAILED tests 1-2
        Failed 2/2 tests, 0.00% okay
t/40ph_type.............ok
t/50cursor..............ok
t/60reauth..............ORACLE_USERID_2 not defined.  Tests skipped.
skipped
        all skipped: no reason given
t/70meta................ok
Failed Test Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
t/30long.t   255 65280   470  557 118.51%  190-470
t/31lob.t    255 65280     2    4 200.00%  1-2
4 tests and 122 subtests skipped.
Failed 2/18 test scripts, 88.89% okay. 283/1883 subtests failed, 84.97% okay.
make: *** [test_dynamic] Error 255

-- 
H.Merijn Brand        Amsterdam Perl Mongers (http://amsterdam.pm.org/)
using perl-5.6.1, 5.8.0 & 633 on HP-UX 10.20 & 11.00, AIX 4.2, AIX 4.3,
     WinNT 4, Win2K pro & WinCE 2.11 often with Tk800.024 &/| DBD-Unify
ftp://ftp.funet.fi/pub/languages/perl/CPAN/authors/id/H/HM/HMBRAND/




