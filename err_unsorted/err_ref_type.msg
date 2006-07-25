From dbi-users-return-19574-Tim.Bunce=pobox.com@perl.org  Wed Jul 23 18:40:02 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h6NHUUA0010501
	for <timbo@localhost>; Wed, 23 Jul 2003 18:40:02 +0100 (BST)
	(envelope-from dbi-users-return-19574-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 23 Jul 2003 18:40:02 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1058948095:10:09585:8; Wed, 23 Jul 2003 08:14:55 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1116163; 23 Jul 2003 8:14 GMT
Received: from dolly1.pobox.com (localhost [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 88C1B21C024
	for <Tim.Bunce@data-plan.com>; Wed, 23 Jul 2003 04:13:51 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by dolly1.pobox.com (Postfix) with SMTP id AA89B21C082
	for <Tim.Bunce@pobox.com>; Wed, 23 Jul 2003 04:13:50 -0400 (EDT)
Received: (qmail 26606 invoked by uid 1005); 23 Jul 2003 08:13:44 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 26590 invoked by uid 76); 23 Jul 2003 08:13:43 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Wed, 23 Jul 2003 01:13:43 -0700
Received: (qmail 16360 invoked by uid 225); 23 Jul 2003 08:13:41 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 16355 invoked by uid 507); 23 Jul 2003 08:13:41 -0000
Received-SPF: unknown
Received: from [212.89.121.1] (HELO babel.morphochem.de) (212.89.121.1) by one.develooper.com (qpsmtpd/0.27-dev) with SMTP; Wed, 23 Jul 2003 01:13:41 -0700
Received: (qmail 5378 invoked from network); 23 Jul 2003 08:54:08 -0000
Received: from unknown (HELO mail.morphochem.de) (10.1.15.5)  by 212.89.121.1 with SMTP; 23 Jul 2003 08:54:08 -0000
Received: (qmail 8984 invoked from network); 23 Jul 2003 08:13:49 -0000
Received: from localhost.morphochem.de (HELO mail) ([127.0.0.1])          (envelope-sender <hendrik.fuss@morphochem.de>)          by localhost.morphochem.de (qmail-ldap-1.03) with SMTP          for <dbi-users@perl.org>; 23 Jul 2003 08:13:49 -0000
Received: from mars.MORPHOCHEM.de ([10.1.8.130])	by mail.morphochem.de (MailMonitor for SMTP v1.2.1 ) ;	Wed, 23 Jul 2003 10:13:49 +0200 (CEST)
Subject: Re: binding to parameters of type REF
From: Hendrik =?ISO-8859-1?Q?Fu=DF?= <hendrik.fuss@morphochem.de>
To: dbi-users@perl.org
In-Reply-To: <1058865345.1241.56.camel@mars>
References: <1058865345.1241.56.camel@mars>
Content-Type: text/plain
Content-Transfer-Encoding: 7bit
X-Mailer: Ximian Evolution 1.0.8 
Date: 23 Jul 2003 10:11:49 +0200
Message-Id: <1058947909.6353.5.camel@mars>
Mime-Version: 1.0
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-0.3 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,LARGE_HEX,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_00_01 version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 1354
Lines: 56

I've also found out, that DBD::Oracle does not support type SQL_REF:
When not using DBD::Proxy I get:

  SQL type 20 for ':p1' is not fully supported,
  bound as SQL_VARCHAR instead

I even get segmentation faults when trying to fetch REF columns. :-(

Any ideas?

> Hi, 
> 
> I'm trying to bind a perl variable to an Oracle table reference with
> Oracle 9.2.0.3, DBD::Proxy and Perl::DBI 1.37 without success. I
> could'nt find help on this in the docs or list archives. I hope this is
> the right place to post.
> 
> In SQL*Plus:
> 
>   SQL> desc getReference
>   FUNCTION getReference RETURNS REF OF TABLETYPE
> 
>   SQL> select getReference() from dual;
> 
>   GETREFERENCE()
>   ----------------------------------------------------------------------
>   0000280209C229D2216EF6A5F4E030010A8D086AD3C204FC6EE0E46501E030010A8D08
>   2CE703C0000E0000
> 
> 
> My code:
> 
>   my $ref = undef;
>   my $sth = $dbh->prepare('BEGIN ? := getReference(); END;');
>   $sth->bind_param_inout(1, \$ref, 128, SQL_REF );
>   $sth->execute();
> 
> yields:
> 
>   PLS-00382: expression is of wrong type
> 
> 
> Even fetching a reference does not work:
> 
>   my $sth = $dbh->prepare('SELECT getReference() FROM DUAL');
>   $sth->execute();
>   ($ref) = $sth->fetchrow_array();
> 
> yields undef in $ref.
> 
> I'd very much appreciate your help.
> cheers,
> Hendrik




