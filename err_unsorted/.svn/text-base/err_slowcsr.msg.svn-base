From calinm@yahoo.com  Tue Apr 30 22:03:11 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3UL3AR27018
	for <timbo@localhost>; Tue, 30 Apr 2002 22:03:10 +0100 (BST)
	(envelope-from calinm@yahoo.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Apr 2002 22:03:10 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020196981:10:23493:39; Tue, 30 Apr 2002 20:03:01 GMT
Received: from silk.pobox.com ([208.210.125.70]) by punt-1.mail.demon.net
           id aa1108477; 30 Apr 2002 20:02 GMT
Received: from dolly1.pobox.com (dolly1.pobox.com [207.106.49.22])
	by silk.pobox.com (Postfix) with ESMTP id 915563FCE8
	for <Tim.Bunce@data-plan.com>; Tue, 30 Apr 2002 14:35:38 -0400 (EDT)
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 343702BFDD
	for <Tim.Bunce@data-plan.com>; Tue, 30 Apr 2002 14:34:38 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from web10005.mail.yahoo.com (web10005.mail.yahoo.com [216.136.130.41])
	by dolly1.pobox.com (Postfix) with SMTP id 6AA822BFA3
	for <Tim.Bunce@pobox.com>; Tue, 30 Apr 2002 14:34:37 -0400 (EDT)
Message-ID: <20020430183429.33340.qmail@web10005.mail.yahoo.com>
Received: from [213.157.171.169] by web10005.mail.yahoo.com via HTTP; Tue, 30 Apr 2002 11:34:29 PDT
Date: Tue, 30 Apr 2002 11:34:29 -0700 (PDT)
From: Calin Medianu <calinm@yahoo.com>
Subject: Re: DBD::Oracle Slow cursors
To: Tim Bunce <Tim.Bunce@pobox.com>
In-Reply-To: <20020430151126.Q16831@dansat.data-plan.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Status: RO
X-Status: A
Content-Length: 2457
Lines: 96

It says here:
http://technet.oracle.com/doc/oracle8i_816/appdev.816/a76975/oci05bnd.htm#421007

that 2 calls are neede to bind a ref , the second is
to OCIBindObject() which I don't see in  dbdimp.c.

Could this be a reason?

Cheers,

Calin

--- Tim Bunce <Tim.Bunce@pobox.com> wrote:
> On Tue, Apr 30, 2002 at 04:04:47PM +0300, Calin
> Medianu wrote:
> > Me again with the slow cursors.
> > 
> > I modified both queries to only return 10 rows.
> > I ran a sniffer (ethereal) on the NIC. It is
> pretty cool, it also decodes TNS.
> > 
> > when I am using the SQL, it works like this, there
> are about 7 packets 
> > received by my workstation to set up the session,
> then all 10 rows are in the 
> > same packet, then there is another packet probably
> saying goodbye.
> > 
> > When I am using the REF cursor, each row comes in
> it's own TNS packet, that 
> > is why it is so slow!
> > 
> > Any idea how to fix it?
> 
> Do a level 9 trace to get a log of the OCI calls and
> confirm that
> the fragment I posted is being called (may be
> helpful to also
> add an extra print statement into that code since
> parsing the
> OCI trace can be painful).
> 
> Assuming the code is being called then as far as I
> can see the code is
> doing the right thing and it's probably an Oracle
> OCI issue.
> 
> You'd need to talk to Oracle support. No need to
> mention perl etc.
> Just talk about your OCI application and provide the
> OCI call trace.
> 
> Let me know what you find out!
> 
> Tim.
> 
> > thanks a lot,
> > 
> > Calin
> > 
> > > On Mon, Apr 29, 2002 at 01:18:53PM -0700, Calin
> Medianu wrote:
> > > > Hello,
> > > >
> > > > I did the following. Wrote a perl script that
> retreves
> > > > data via a straight select from the database.
> Then I
> > > > wrote a stored procedure returning a ref
> cursor open
> > > > on the same select statement and retrieved the
> data as
> > > > well. Using the REF CURSOR/ sotred procedure
> was about
> > > > 3 time slower, that is 40 seconds instead of
> around
> > > > 10.
> > > >
> > > > Is this normal? Is this a problem with oracle
> or with
> > > > DBD::Oracle?
> > >
> > > DBD::Oracle. It probably isn't setting up a row
> cache for the ref cursor.
> > >
> > > Get a level 3 trace and look for the
> "dbd_describe'd" line for the
> > > ref cursor.
> > >
> > > Tim.


__________________________________________________
Do You Yahoo!?
Yahoo! Health - your guide to health and wellness
http://health.yahoo.com

From calinm@yahoo.com  Fri May  3 13:48:06 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g43Cm5R50489
	for <timbo@localhost>; Fri, 3 May 2002 13:48:05 +0100 (BST)
	(envelope-from calinm@yahoo.com)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 03 May 2002 13:48:05 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020429421:10:02019:143; Fri, 03 May 2002 12:37:01 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-1.mail.demon.net
           id aa1123562; 3 May 2002 12:36 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id D7BD1725A1
	for <Tim.Bunce@data-plan.com>; Fri,  3 May 2002 08:36:41 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from web10008.mail.yahoo.com (web10008.mail.yahoo.com [216.136.130.44])
	by wormwood.pobox.com (Postfix) with SMTP id 3088772674
	for <Tim.Bunce@pobox.com>; Fri,  3 May 2002 08:36:41 -0400 (EDT)
Message-ID: <20020503123640.19648.qmail@web10008.mail.yahoo.com>
Received: from [213.157.171.169] by web10008.mail.yahoo.com via HTTP; Fri, 03 May 2002 05:36:40 PDT
Date: Fri, 3 May 2002 05:36:40 -0700 (PDT)
From: Calin Medianu <calinm@yahoo.com>
Subject: Re: DBD::Oracle Slow cursors
To: Tim Bunce <Tim.Bunce@pobox.com>
In-Reply-To: <20020501155718.S16831@dansat.data-plan.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Status: RO
Content-Length: 3619
Lines: 150

Sure,

I'll give it a try next week.

Cheers,

Calin
--- Tim Bunce <Tim.Bunce@pobox.com> wrote:
> Thanks. I'll take a look when I get to DBD::Oracle
> again.
> 
> I think the last row of that table applies and it
> doesn't refer to OCIBindObject():
>     REF CURSOR variables 
>     SQLT_RSET 
>     Allocate a statement handle, OCIStmt, and then
> bind its address
>     (OCIStmt **) using the SQLT_RSET datatype.
> Note that SQLT_REF isn't the same as SQLT_RSET.
> 
> You could always try patching it yourself!
> 
> Tim.
> 
> 
> On Tue, Apr 30, 2002 at 11:34:29AM -0700, Calin
> Medianu wrote:
> > It says here:
> >
>
http://technet.oracle.com/doc/oracle8i_816/appdev.816/a76975/oci05bnd.htm#421007
> > 
> > that 2 calls are neede to bind a ref , the second
> is
> > to OCIBindObject() which I don't see in  dbdimp.c.
> > 
> > Could this be a reason?
> > 
> > Cheers,
> > 
> > Calin
> > 
> > --- Tim Bunce <Tim.Bunce@pobox.com> wrote:
> > > On Tue, Apr 30, 2002 at 04:04:47PM +0300, Calin
> > > Medianu wrote:
> > > > Me again with the slow cursors.
> > > > 
> > > > I modified both queries to only return 10
> rows.
> > > > I ran a sniffer (ethereal) on the NIC. It is
> > > pretty cool, it also decodes TNS.
> > > > 
> > > > when I am using the SQL, it works like this,
> there
> > > are about 7 packets 
> > > > received by my workstation to set up the
> session,
> > > then all 10 rows are in the 
> > > > same packet, then there is another packet
> probably
> > > saying goodbye.
> > > > 
> > > > When I am using the REF cursor, each row comes
> in
> > > it's own TNS packet, that 
> > > > is why it is so slow!
> > > > 
> > > > Any idea how to fix it?
> > > 
> > > Do a level 9 trace to get a log of the OCI calls
> and
> > > confirm that
> > > the fragment I posted is being called (may be
> > > helpful to also
> > > add an extra print statement into that code
> since
> > > parsing the
> > > OCI trace can be painful).
> > > 
> > > Assuming the code is being called then as far as
> I
> > > can see the code is
> > > doing the right thing and it's probably an
> Oracle
> > > OCI issue.
> > > 
> > > You'd need to talk to Oracle support. No need to
> > > mention perl etc.
> > > Just talk about your OCI application and provide
> the
> > > OCI call trace.
> > > 
> > > Let me know what you find out!
> > > 
> > > Tim.
> > > 
> > > > thanks a lot,
> > > > 
> > > > Calin
> > > > 
> > > > > On Mon, Apr 29, 2002 at 01:18:53PM -0700,
> Calin
> > > Medianu wrote:
> > > > > > Hello,
> > > > > >
> > > > > > I did the following. Wrote a perl script
> that
> > > retreves
> > > > > > data via a straight select from the
> database.
> > > Then I
> > > > > > wrote a stored procedure returning a ref
> > > cursor open
> > > > > > on the same select statement and retrieved
> the
> > > data as
> > > > > > well. Using the REF CURSOR/ sotred
> procedure
> > > was about
> > > > > > 3 time slower, that is 40 seconds instead
> of
> > > around
> > > > > > 10.
> > > > > >
> > > > > > Is this normal? Is this a problem with
> oracle
> > > or with
> > > > > > DBD::Oracle?
> > > > >
> > > > > DBD::Oracle. It probably isn't setting up a
> row
> > > cache for the ref cursor.
> > > > >
> > > > > Get a level 3 trace and look for the
> > > "dbd_describe'd" line for the
> > > > > ref cursor.
> > > > >
> > > > > Tim.
> > 
> > 
> > __________________________________________________
> > Do You Yahoo!?
> > Yahoo! Health - your guide to health and wellness
> > http://health.yahoo.com


__________________________________________________
Do You Yahoo!?
Yahoo! Health - your guide to health and wellness
http://health.yahoo.com

