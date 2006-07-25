From dbi-users-return-1743-Tim.Bunce=ig.co.uk@perl.org  Wed Apr 11 04:00:48 2001
Return-Path: <dbi-users-return-1743-Tim.Bunce=ig.co.uk@perl.org>
Received: from oink by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id EAA17912; Wed, 11 Apr 2001 04:00:48 +0100 (BST)
Received: from 194.217.242.36 by oink with SMTP (PP) id <02579-1@oink>;
          Sat, 11 Apr 1970 04:00:28 +0100
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 986956750:10:04398:0; Wed, 11 Apr 2001 02:39:10 GMT
Received: from tmtowtdi.perl.org ([209.85.3.25]) by punt-1.mail.demon.net 
          id aa1106187; 11 Apr 2001 2:39 GMT
Received: (qmail 32618 invoked by uid 508); 11 Apr 2001 02:39:06 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 32603 invoked from network); 11 Apr 2001 02:39:05 -0000
Received: from owns.warpcore.org (216.81.249.18) by tmtowtdi.perl.org with SMTP;
          11 Apr 2001 02:39:05 -0000
Received: (from thebrain@localhost) by owns.warpcore.org (8.11.1/8.11.1) 
          id f3B2cxH06298 for dbi-users@perl.org;
          Tue, 10 Apr 2001 21:38:59 -0500
Date: Tue, 10 Apr 2001 21:38:59 -0500
From: Stephen Clouse <stephenc@theiqgroup.com>
To: dbi-users@perl.org
Subject: Bizarre DBD::Oracle Segfault
Message-ID: <20010410213859.B2766@owns.warpcore.org>
Mail-Followup-To: dbi-users@perl.org
Mime-Version: 1.0
Content-Type: text/plain
Content-Disposition: inline; filename="msg.pgp"
User-Agent: Mutt/1.2.5i
Status: RO
Content-Length: 1918
Lines: 54

-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

I sent an email to the dbi-users list about a number of DBD::Oracle CLOB 
handling problems waaaaaaaaaaaaaaay back (end of January or so) that today
someone dug up and inquired if I had ever found fixes for what I had pointed
out.

The problems outlined that day turned out to be the test script itself, which
was doing so much bizarre stuff on one statement that DBD::Oracle just went to
sleep instead (and so was the actual program that instigated the writing of the 
test script).

Well, all but one problem was the script.  This, the most serious one, continues
to linger:

my $st = $db->prepare('INSERT INTO foo (col1, col2, col3) VALUES (?,?,?)');
$st->bind_param(3,undef,{ ora_type => ORA_CLOB });
$st->execute('A','A',undef);

On Linux, DBI 1.15, Oracle 8.1.6, and DBD::Oracle 1.06, this segfaults on the
execute.  Unfortunately this manifests itself too deep in Oracle for me to
debug.

The bizarre part is, either of the two snippets below will work:

my $st = $db->prepare('INSERT INTO foo (col1, col2, col3) VALUES (?,?,?)');
$st->bind_param(3,undef,{ ora_type => ORA_CLOB });
$st->execute('A','A','');
$st->execute('B','B',undef);

my $st = $db->prepare('INSERT INTO foo (col1, col2, col3) VALUES (?,?,?)');
$st->bind_param(3,undef,{ ora_type => ORA_CLOB });
$st->execute('A','A',$lobvalue);
$st->execute('B','B',undef);

It's only when binding undef as the LOB value in the very first execute of a
statement that the segfault occurs.  At any other time, it's kosher.  That
qualifies as bizarre in my book.

Your guess is better than mine.

- -- 
Stephen Clouse <stephenc@theiqgroup.com>
Senior Programmer, IQ Coordinator Project Lead
The IQ Group, Inc. <http://www.theiqgroup.com/>

-----BEGIN PGP SIGNATURE-----
Version: PGP 6.5.8

iQA+AwUBOtPDwgOGqGs0PadnEQLmtgCeJHTStLu8Q8oFb9UQ4995f8vhZH8Al1p6
RD5m0FEJH2tQiY0+b6542mQ=
=L0M+
-----END PGP SIGNATURE-----

