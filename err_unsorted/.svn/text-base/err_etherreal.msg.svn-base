From dbi-users-return-11185-Tim.Bunce=pobox.com@perl.org  Tue Apr 30 14:47:44 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3UDliR22576
	for <timbo@localhost>; Tue, 30 Apr 2002 14:47:44 +0100 (BST)
	(envelope-from dbi-users-return-11185-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.23]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Apr 2002 14:47:44 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020172466:10:24548:59; Tue, 30 Apr 2002 13:14:26 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1023391; 30 Apr 2002 13:13 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id A94562C075
	for <Tim.Bunce@data-plan.com>; Tue, 30 Apr 2002 09:12:33 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by dolly1.pobox.com (Postfix) with SMTP id F24B22BFBE
	for <Tim.Bunce@pobox.com>; Tue, 30 Apr 2002 09:12:32 -0400 (EDT)
Received: (qmail 36589 invoked by uid 1005); 30 Apr 2002 13:12:28 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 36168 invoked by uid 76); 30 Apr 2002 13:10:41 -0000
Content-Type: text/plain;
  charset="iso-8859-1"
From: Calin Medianu <calinm@yahoo.com>
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: DBD::Oracle Slow cursors
Date: Tue, 30 Apr 2002 16:04:47 +0300
X-Mailer: KMail [version 1.3.2]
References: <20020429201853.52283.qmail@web10007.mail.yahoo.com> <20020429233138.E16831@dansat.data-plan.com>
In-Reply-To: <20020429233138.E16831@dansat.data-plan.com>
Cc: dbi-users@perl.org
MIME-Version: 1.0
Message-Id: <20020430131233.F24B22BFBE@dolly1.pobox.com>
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id g3UDliR22576
Status: RO
X-Status: A
Content-Length: 1213
Lines: 38

[Add note to DBD::Oracle docs about using ethereal to sniff Oracle packets]
[Not sure if this bug got fixed yet. Maybe not.]

Me again with the slow cursors.

I modified both queries to only return 10 rows.
I ran a sniffer (ethereal) on the NIC. It is pretty cool, it also decodes TNS.

when I am using the SQL, it works like this, there are about 7 packets 
received by my workstation to set up the session, then all 10 rows are in the 
same packet, then there is another packet probably saying goodbye.

When I am using the REF cursor, each row comes in it's own TNS packet, that 
is why it is so slow!

Any idea how to fix it?

thanks a lot,

Calin

> On Mon, Apr 29, 2002 at 01:18:53PM -0700, Calin Medianu wrote:
> > Hello,
> >
> > I did the following. Wrote a perl script that retreves
> > data via a straight select from the database. Then I
> > wrote a stored procedure returning a ref cursor open
> > on the same select statement and retrieved the data as
> > well. Using the REF CURSOR/ sotred procedure was about
> > 3 time slower, that is 40 seconds instead of around
> > 10.
> >
> > Is this normal? Is this a problem with oracle or with
> > DBD::Oracle?
>
> DBD::Oracle. It probably isn't setting up a row cache for the ref cursor.
>
> Get a level 3 trace and look for the "dbd_describe'd" line for the
> ref cursor.
>
> Tim.

