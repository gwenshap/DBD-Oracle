From dbi-users-return-19548-Tim.Bunce=pobox.com@perl.org  Tue Jul 22 07:40:59 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6M6UUD7096422
	for <timbo@localhost>; Tue, 22 Jul 2003 07:40:58 +0100 (BST)
	(envelope-from dbi-users-return-19548-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 22 Jul 2003 07:40:58 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1058814697:11:26523:33; Mon, 21 Jul 2003 19:11:37 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1126786; 21 Jul 2003 19:11 GMT
Received: from dolly1.pobox.com (localhost [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id E855B21C37F
	for <Tim.Bunce@data-plan.com>; Mon, 21 Jul 2003 15:11:18 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by dolly1.pobox.com (Postfix) with SMTP id 9010121C236
	for <Tim.Bunce@pobox.com>; Mon, 21 Jul 2003 15:11:17 -0400 (EDT)
Received: (qmail 66848 invoked by uid 1005); 21 Jul 2003 19:11:15 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 66832 invoked by uid 76); 21 Jul 2003 19:11:15 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Mon, 21 Jul 2003 12:11:15 -0700
Received: (qmail 559 invoked by uid 225); 21 Jul 2003 19:11:08 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 552 invoked by uid 507); 21 Jul 2003 19:11:07 -0000
Received-SPF: unknown
Received: from sneakemail.com (HELO monkey.sneakemail.com) (207.106.87.13) by one.develooper.com (qpsmtpd/0.27-dev) with SMTP; Mon, 21 Jul 2003 12:11:03 -0700
Received: (qmail 22505 invoked by uid 501); 21 Jul 2003 19:10:57 -0000
Received: (sneakemail censored 13502-46198 #3); 21 Jul 2003 19:10:57 -0000
Received: (sneakemail censored 13502-46198 #2); 21 Jul 2003 19:10:57 -0000
Received: (sneakemail censored 13502-46198 #1); 21 Jul 2003 19:10:57 -0000
Date: Mon, 21 Jul 2003 21:10:53 +0200
From: "Wolfgang Weisselberg" <mui9rjw001@sneakemail.com>
To: dbi-users@perl.org
Subject: DBD::Oracle and unicode-NCLOBs leads to ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead)
Message-ID: <13502-46198@sneakemail.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.4.1i
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=0.6 required=7.0 tests=CARRIAGE_RETURNS,FROM_ENDS_IN_NUMS,FROM_HAS_MIXED_NUMS,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_MUTT version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
X-Status: A
Content-Length: 6055
Lines: 132

Hello all!

Even after extensive googling and looking through the docs I fail
to fetch NCLOBs from an Oracle 9.2i database where the national
character set is unicode.

I believe it has been done before, but I could not find anything ... 
I would be grateful for any pointers.


NCLOBs work like CLOBs when the national character set is not
unicode, even with the old DBI 1.21 and DBD::Oracle 1.12 on an
Oracle 8 client.  NVarchar2 and NChar work OK even with unicode.

Setting NSL_LANG to AMERICAN_AMERICA.UTF8 or .AL32UTF8 does not
help, as I suspected.

I tried using Oracle 9.2i (the DB is using 9.2i) on a Debian
Linux box.  I upgraded DBI to 1.37 and DBD::Oracle to 1.14 (the
newest versions according to CPAN).  I got zero errors on make
test with both.  Perl is Debian's normal "perl5 (revision 5.0
version 6 subversion 1)".

A simple 
    select memo from unicode_test
(memo being the NCLOB field) fails (again, only with the national
charset being unicode).

The relevant code snippet (RaiseError being set, of course):

| $| = 1;
| print "DBI:  $DBI::VERSION\n", 
|       "DBD::Oracle  $DBD::Oracle::VERSION\n";
| my $sth = $dbh->prepare("select memo from unicode_test");
| $sth->execute();
| 
| while ( my ($memo) = $sth->fetchrow_array() ) {
|     print Dumper $memo;
| }
| exit;


The output: 

| DBI:  1.37
| DBD::Oracle  1.14
| $VAR1 = '';
| $VAR1 = '';
| DBD::Oracle::st fetchrow_array failed: ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead) [for statement ``select memo from unicode_test'' with params: ]) at nclobtest.pl line 77.
| DBD::Oracle::st fetchrow_array failed: ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead) [for statement ``select memo from unicode_test'' with params: ]) at nclobtest.pl line 77.



Running with tracelevel 3:
    [...]
|     dbd_st_prepare'd sql SELECT
|     dbd_describe SELECT (EXPLICIT, lb 99999999)...
|     fbh 1: 'MEMO'	NO null , otype 112->112, dbsize 4000/4000, p0.s0
|     dbd_describe'd 1 columns (row bytes: 4000 max, 4000 est avg, cache: 6)
|     <- prepare= DBI::st=HASH(0x831643c) at nclobtest.pl line 78 via nclobtest.pl line 60
|     -> execute for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
|     dbd_st_execute SELECT (out0, lob0)...
|     dbd_st_execute SELECT returned (SUCCESS, rpc0, fn4, out0)
|     <- execute= '0E0' at nclobtest.pl line 79 via nclobtest.pl line 60
|     -> fetchrow_array for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
|     dbd_st_fetch 1 fields...
|     dbih_setup_fbav for 1 fields => 0x82f8e34
|     dbd_st_fetch 1 fields SUCCESS
|        OCILobRead field 2 SKIPPED: LOBlen 0, LongReadLen 99999999, BufLen 0, Got 0
|     <- fetchrow_array= ( '' ) [1 items] row1 at nclobtest.pl line 81 via nclobtest.pl line 60
| $VAR1 = '';
[EXACTLY the same "-> fetchrow_array" to "<- fetchrow_array" again]
| $VAR1 = '';
|     -> fetchrow_array for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
|     dbd_st_fetch 1 fields...
|     dbd_st_fetch 1 fields SUCCESS
|        OCILobRead field 2 ERROR: LOBlen 6c, LongReadLen 99999999c, BufLen 24b, Got 6c
|     !! ERROR: 24806 'ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead)'
|     <- fetchrow_array= ( ) [0 items] row3 at nclobtest.pl line 81 via nclobtest.pl line 60
| 1   -> FETCH for DBD::Oracle::st (DBI::st=HASH(0x82f8e28)~INNER 'ParamValues')
|        error: 24806 'ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead)'
| 1   <- FETCH= HASH(0x831661c)0keys at nclobtest.pl line 81 via nclobtest.pl line 60
| DBD::Oracle::st fetchrow_array failed: ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead) [for statement ``select memo from unicode_test'' with params: ]) at nclobtest.pl line 81.
| DBD::Oracle::st fetchrow_array failed: ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead) [for statement ``select memo from unicode_test'' with params: ]) at nclobtest.pl line 81.



Tracelevel 9 (yes, it's a bit verbose :-/ ) 

[...]
| OCIDescriptorAlloc(0x831c058,0x8395228,OCI_DTYPE_LOB,0,0)
|     fbh 1: 'MEMO'	NO null , otype 112->112, dbsize 4000/4000, p0.s0
| OCIAttrSet(0x8335b34,OCI_HTYPE_STMT,0xbffff30c,4,11,0x832d5a4)=SUCCESS
| OCIDefineByPos(0x8335b34,0x8395224,0x832d5a4,1,0x8395228,-1,112,0x83414e0,0x83414f0,0x8341500,0)=SUCCESS
|     dbd_describe'd 1 columns (row bytes: 4000 max, 4000 est avg, cache: 6)
|     <- prepare= DBI::st=HASH(0x831643c) at nclobtest.pl line 78 via nclobtest.pl line 60
|     -> execute for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
[...]
|     -> fetchrow_array for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
|     dbd_st_fetch 1 fields...
| OCIStmtFetch(0x8335b34,0x832d5a4,1,2,0)=SUCCESS
|     dbih_setup_fbav for 1 fields => 0x82f8e34
|     dbd_st_fetch 1 fields SUCCESS
| OCILobGetLength(0x832d530,0x832d5a4,0x832c69c,0xbffff31c)=SUCCESS
|        OCILobRead field 2 SKIPPED: LOBlen 0, LongReadLen 99999999, BufLen 0, Got 0
|         0 (rc=0): ''
|     <- fetchrow_array= ( '' ) [1 items] row1 at nclobtest.pl line 81 via nclobtest.pl line 60
| $VAR1 = '';
[EXACTLY the same "-> fetchrow_array" to "<- fetchrow_array" again]
| $VAR1 = '';
|     -> fetchrow_array for DBD::Oracle::st (DBI::st=HASH(0x831643c)~0x82f8e28)
|     dbd_st_fetch 1 fields...
| OCIStmtFetch(0x8335b34,0x832d5a4,1,2,0)=SUCCESS
|     dbd_st_fetch 1 fields SUCCESS
| OCILobGetLength(0x832d530,0x832d5a4,0x832c69c,0xbffff31c)=SUCCESS
| OCILobRead(0x832d530,0x832d5a4,0x832c69c,0xbffff318,1,0x8394da0,24,(nil),(nil),0,1)=ERROR
|        OCILobRead field 2 ERROR: LOBlen 6c, LongReadLen 99999999c, BufLen 24b, Got 6c
| OCIErrorGet(0x832d5a4,1,"<NULL>",0xbfffee88,"ORA-24806: LOB form mismatch
| ",1024,2)=SUCCESS
|     OCIErrorGet after OCILobRead (er1:ok): -1, 24806: ORA-24806: LOB form mismatch
| 
| OCIErrorGet(0x832d5a4,2,"<NULL>",0xbfffee88,"ORA-24806: LOB form mismatch
| ",1024,2)=NO_DATA
|         0 (rc=0): undef
|     !! ERROR: 24806 'ORA-24806: LOB form mismatch (DBD ERROR: OCILobRead)'
|     <- fetchrow_array= ( ) [0 items] row3 at nclobtest.pl line 81 via nclobtest.pl line 60
[gets and prints error message]


Any ideas anyone?

-Wolfgang

