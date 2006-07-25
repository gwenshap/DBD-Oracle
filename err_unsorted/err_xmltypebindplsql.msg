From dbi-users-return-11068-Tim.Bunce=pobox.com@perl.org  Thu Apr 25 11:02:42 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3PA2gK34525
	for <timbo@localhost>; Thu, 25 Apr 2002 11:02:42 +0100 (BST)
	(envelope-from dbi-users-return-11068-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.21]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 25 Apr 2002 11:02:42 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1019721492:10:18778:60; Thu, 25 Apr 2002 07:58:12 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1109782; 25 Apr 2002 7:58 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 791692BF11
	for <Tim.Bunce@data-plan.com>; Thu, 25 Apr 2002 03:58:08 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by dolly1.pobox.com (Postfix) with SMTP id 976FB2BEE4
	for <Tim.Bunce@pobox.com>; Thu, 25 Apr 2002 03:58:07 -0400 (EDT)
Received: (qmail 84467 invoked by uid 1005); 25 Apr 2002 07:58:05 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 77923 invoked by uid 76); 24 Apr 2002 23:08:56 -0000
Date: Wed, 24 Apr 2002 19:08:54 -0400
From: Mark Stillwell <marklee@ufl.edu>
To: dbi-users-help@perl.org, dbi-users@perl.org
Subject: Oracle 9 XMLTYPE insert
Message-ID: <20020424190852.C22854@byrd.biostat.ufl.edu>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5.1i
Status: RO
Content-Length: 1469
Lines: 43

I'm using DBI 1.21 and DBD 1.12 with an oracle9i database backend.

Here is my problem, I have a table named 'test' with three fields: eid
(integer), x (SYS.XMLTYPE) and formname (text)

I create a database handler and connect to the database just fine.

I create a new statement handler with the following command:

$sth = $dbh->prepare("INSERT INTO test (eid, x, formname) VALUES (?,
SYS.XMLTYPE.CREATEXML(?), ?");

I loop over some data, $eid gets and integer, $xmlvalue gets a string,
and $formname gets a string.  So long as $xmlvalue is relatively short
$sth->execute($eid, $xmlvalue, $formname); works great, but as soon as
it becomes long enough to force the use of clob's I have a problem.

So I tried the following:

$sth->bind_param(1, $i);
$sth->bind_param(2, $xmlvalue, { ora_type => ORA_CLOB });
$sth->bind_param(3, $intable);
$sth->execute;

This works great if column 'x' is a normal CLOB and I omit the
sys.xmltype.createxml statement above, but when 'x' is of type
sys.xmltype I get the following error:

nvalid LOB locator specified
ORA-06512: at "SYS.XMLTYPE", line 0

Right now I've hacked the setup so there is a supplemental table called
'y' of type CLOB that I submit to, then I do $dbh->do("UPDATE test SET x
= SYS.XMLTYPE.CREATEXML(y)");, which works but doesn't seem like the
right way to do this.

Is there any way to do what I want in the current version of
DBI/OracleDBD? 

-- 
Mark Stillwell
marklee@ufl.edu
http://plaza.ufl.edu/marklee/

From dbi-users-return-11340-Tim.Bunce=pobox.com@perl.org  Wed May  8 16:11:46 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g48FBjo24814
	for <timbo@localhost>; Wed, 8 May 2002 16:11:45 +0100 (BST)
	(envelope-from dbi-users-return-11340-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 08 May 2002 16:11:45 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020870336:20:08175:2; Wed, 08 May 2002 15:05:36 GMT
Received: from cali-3.pobox.com ([64.71.166.116]) by punt-2.mail.demon.net
           id aa2109147; 8 May 2002 15:05 GMT
Received: from cali-3.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-3.pobox.com (Postfix) with ESMTP id 68FE23E6D4
	for <Tim.Bunce@data-plan.com>; Wed,  8 May 2002 11:01:49 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by cali-3.pobox.com (Postfix) with SMTP id 33A783E64D
	for <Tim.Bunce@pobox.com>; Wed,  8 May 2002 11:01:49 -0400 (EDT)
Received: (qmail 65232 invoked by uid 1005); 8 May 2002 15:01:47 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 60079 invoked by uid 76); 8 May 2002 14:50:53 -0000
From: "Ben Middleton" <ben.middleton@mediasurface.com>
To: <marklee@ufl.edu>
Cc: <dbi-users@perl.org>
Subject: Re: Oracle 9 XMLTYPE insert
Date: Wed, 8 May 2002 15:50:47 +0100
Message-ID: <LAEFKFAOHIHFEAJGOIHNKEEACMAA.ben.middleton@mediasurface.com>
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-8859-1"
Content-Transfer-Encoding: 7bit
X-Priority: 3 (Normal)
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook IMO, Build 9.0.2416 (9.0.2911.0)
Importance: Normal
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2600.0000
Status: RO
Content-Length: 1311
Lines: 39

Hi.

Not sure if you ever resolved this:

> I'm using DBI 1.21 and DBD 1.12 with an oracle9i database backend.

> Here is my problem, I have a table named 'test' with three fields:
> eid (integer), x (SYS.XMLTYPE) and formname (text)

> I create a new statement handler with the following command:

> $sth = $dbh->prepare("INSERT INTO test (eid, x, formname) VALUES (?,
> SYS.XMLTYPE.CREATEXML(?), ?");

....

> Invalid LOB locator specified
> ORA-06512: at "SYS.XMLTYPE", line 0

> Right now I've hacked the setup so there is a supplemental table
> called 'y' of type CLOB that I submit to, then I do $dbh->do("UPDATE
> test SET x= SYS.XMLTYPE.CREATEXML(y)");, which works but doesn't seem
> like the right way to do this.

> Is there any way to do what I want in the current version of
> DBI/OracleDBD?

I don't think that the current DBI/DBD can bind a CLOB to a PL/SQL function
(which is all the CREATEXML function is) - hence you will have to go with
the intermediate CLOB table solution.

Incidentally, if you are using Oracle9i - have you tried using a TEMPORARY
TABLE with a CLOB column (see SQL Reference Guide)? If setup correctly, this
is automatically truncated at the end of a transaction, is managed by the
Server, and provides some efficiency benefits. We use this here quite
effectively.

Ben.


