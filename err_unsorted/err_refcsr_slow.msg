From dbi-users-return-11175-Tim.Bunce=pobox.com@perl.org  Mon Apr 29 23:12:51 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3TMCpR17212
	for <timbo@localhost>; Mon, 29 Apr 2002 23:12:51 +0100 (BST)
	(envelope-from dbi-users-return-11175-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 29 Apr 2002 23:12:51 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020117986:10:17770:92; Mon, 29 Apr 2002 22:06:26 GMT
Received: from wormwood.pobox.com ([208.210.125.20]) by punt-1.mail.demon.net
           id aa1017591; 29 Apr 2002 22:06 GMT
Received: from wormwood.pobox.com (localhost.pobox.com [127.0.0.1])
	by wormwood.pobox.com (Postfix) with ESMTP id 975037274A
	for <Tim.Bunce@data-plan.com>; Mon, 29 Apr 2002 18:01:37 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by wormwood.pobox.com (Postfix) with SMTP id ED2897273F
	for <Tim.Bunce@pobox.com>; Mon, 29 Apr 2002 18:01:34 -0400 (EDT)
Received: (qmail 70462 invoked by uid 1005); 29 Apr 2002 21:59:33 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 20335 invoked by uid 76); 29 Apr 2002 20:18:55 -0000
Message-ID: <20020429201853.52283.qmail@web10007.mail.yahoo.com>
Date: Mon, 29 Apr 2002 13:18:53 -0700 (PDT)
From: Calin Medianu <calinm@yahoo.com>
Reply-To: cmedianu@sfu.ca
Subject: DBD::Oracle Slow cursors
To: dbi-users@perl.org
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Status: RO
X-Status: A
Content-Length: 568
Lines: 21

Hello,

I did the following. Wrote a perl script that retreves
data via a straight select from the database. Then I
wrote a stored procedure returning a ref cursor open
on the same select statement and retrieved the data as
well. Using the REF CURSOR/ sotred procedure was about
3 time slower, that is 40 seconds instead of around
10.

Is this normal? Is this a problem with oracle or with
DBD::Oracle?

Thanks,

Calin Medianu

__________________________________________________
Do You Yahoo!?
Yahoo! Health - your guide to health and wellness
http://health.yahoo.com

From dbi-users-return-11177-Tim.Bunce=pobox.com@perl.org  Tue Apr 30 00:06:36 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3TN6aR17980
	for <timbo@localhost>; Tue, 30 Apr 2002 00:06:36 +0100 (BST)
	(envelope-from dbi-users-return-11177-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Apr 2002 00:06:36 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020119533:20:05733:4; Mon, 29 Apr 2002 22:32:13 GMT
Received: from cali-1.pobox.com ([64.71.166.114]) by punt-2.mail.demon.net
           id aa2005393; 29 Apr 2002 22:32 GMT
Received: from cali-1.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-1.pobox.com (Postfix) with ESMTP id 4E6B73E6BF
	for <Tim.Bunce@data-plan.com>; Mon, 29 Apr 2002 18:32:00 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [209.85.157.220])
	by cali-1.pobox.com (Postfix) with SMTP id BF79C3E6A0
	for <Tim.Bunce@pobox.com>; Mon, 29 Apr 2002 18:31:59 -0400 (EDT)
Received: (qmail 87860 invoked by uid 1005); 29 Apr 2002 22:31:59 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 87844 invoked by uid 76); 29 Apr 2002 22:31:58 -0000
Received: from mail01.svc.cra.dublin.eircom.net (HELO mail01.svc.cra.dublin.eircom.net) (159.134.118.17)
  by onion.perl.org (qpsmtpd/0.07) with SMTP; Mon Apr 29 22:31:58 2002 -0000
Received: (qmail 21911 messnum 119827 invoked from network[159.134.167.97/p865.as1.limerick1.eircom.net]); 29 Apr 2002 22:31:29 -0000
Received: from p865.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.167.97)
  by mail01.svc.cra.dublin.eircom.net (qp 21911) with SMTP; 29 Apr 2002 22:31:29 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g3TMVcR17579;
	Mon, 29 Apr 2002 23:31:38 +0100 (BST)
	(envelope-from timbo)
Date: Mon, 29 Apr 2002 23:31:38 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: cmedianu@sfu.ca
Cc: dbi-users@perl.org
Subject: Re: DBD::Oracle Slow cursors
Message-ID: <20020429233138.E16831@dansat.data-plan.com>
References: <20020429201853.52283.qmail@web10007.mail.yahoo.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5i
In-Reply-To: <20020429201853.52283.qmail@web10007.mail.yahoo.com>; from calinm@yahoo.com on Mon, Apr 29, 2002 at 01:18:53PM -0700
Content-Length: 651
Lines: 20

On Mon, Apr 29, 2002 at 01:18:53PM -0700, Calin Medianu wrote:
> Hello,
> 
> I did the following. Wrote a perl script that retreves
> data via a straight select from the database. Then I
> wrote a stored procedure returning a ref cursor open
> on the same select statement and retrieved the data as
> well. Using the REF CURSOR/ sotred procedure was about
> 3 time slower, that is 40 seconds instead of around
> 10.
> 
> Is this normal? Is this a problem with oracle or with
> DBD::Oracle?

DBD::Oracle. It probably isn't setting up a row cache for the ref cursor.

Get a level 3 trace and look for the "dbd_describe'd" line for the
ref cursor.

Tim.

From calinm@yahoo.com  Tue Apr 30 22:02:56 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g3UL2tR26878
	for <timbo@localhost>; Tue, 30 Apr 2002 22:02:55 +0100 (BST)
	(envelope-from calinm@yahoo.com)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Apr 2002 22:02:55 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020198219:10:21718:114; Tue, 30 Apr 2002 20:23:39 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1101732; 30 Apr 2002 20:23 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id C6B4A2BFB4
	for <Tim.Bunce@data-plan.com>; Tue, 30 Apr 2002 16:23:25 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from web10004.mail.yahoo.com (web10004.mail.yahoo.com [216.136.130.40])
	by dolly1.pobox.com (Postfix) with SMTP id 527BD2BF3D
	for <Tim.Bunce@pobox.com>; Tue, 30 Apr 2002 16:23:25 -0400 (EDT)
Message-ID: <20020430202321.54825.qmail@web10004.mail.yahoo.com>
Received: from [213.157.171.169] by web10004.mail.yahoo.com via HTTP; Tue, 30 Apr 2002 13:23:20 PDT
Date: Tue, 30 Apr 2002 13:23:20 -0700 (PDT)
From: Calin Medianu <calinm@yahoo.com>
Subject: Re: DBD::Oracle Slow cursors
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: dbi-users@perl.org
In-Reply-To: <20020430140517.P16831@dansat.data-plan.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Status: RO
X-Status: A
Content-Length: 425
Lines: 18

I "Solved" the problem. For Now.. I did
perl Makefile.PL -8

hoping that the buggy code would be recently added,
and it was. Now both the select and the cursor return
the data at the same speed, meaning fast..

Am I am missing much by not using the code for Oracle
8?

Thanks,

Calin

__________________________________________________
Do You Yahoo!?
Yahoo! Health - your guide to health and wellness
http://health.yahoo.com

From timbo@dansat.data-plan.com  Wed May  1 16:49:55 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g41FnsR33994
	for <timbo@localhost>; Wed, 1 May 2002 16:49:54 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 01 May 2002 16:49:54 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1020265865:20:10671:66; Wed, 01 May 2002 15:11:05 GMT
Received: from silk.pobox.com ([208.210.125.70]) by punt-2.mail.demon.net
           id aa2122069; 1 May 2002 15:10 GMT
Received: from cali-3.pobox.com (cali-3.pobox.com [64.71.166.116])
	by silk.pobox.com (Postfix) with ESMTP id F29CC3FDF2
	for <Tim.Bunce@data-plan.com>; Wed,  1 May 2002 11:09:52 -0400 (EDT)
Received: from cali-3.pobox.com (localhost.localdomain [127.0.0.1])
	by cali-3.pobox.com (Postfix) with ESMTP id E3A943E689
	for <Tim.Bunce@data-plan.com>; Wed,  1 May 2002 10:57:15 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail03.svc.cra.dublin.eircom.net (mail03.svc.cra.dublin.eircom.net [159.134.118.19])
	by cali-3.pobox.com (Postfix) with SMTP id D1F523E688
	for <Tim.Bunce@pobox.com>; Wed,  1 May 2002 10:57:14 -0400 (EDT)
Received: (qmail 96042 messnum 564683 invoked from network[159.134.166.63/p575.as1.limerick1.eircom.net]); 1 May 2002 14:57:13 -0000
Received: from p575.as1.limerick1.eircom.net (HELO dansat.data-plan.com) (159.134.166.63)
  by mail03.svc.cra.dublin.eircom.net (qp 96042) with SMTP; 1 May 2002 14:57:13 -0000
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.11.6/8.11.6) id g41EvIh33626;
	Wed, 1 May 2002 15:57:18 +0100 (BST)
	(envelope-from timbo)
Date: Wed, 1 May 2002 15:57:18 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Calin Medianu <calinm@yahoo.com>
Cc: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: DBD::Oracle Slow cursors
Message-ID: <20020501155718.S16831@dansat.data-plan.com>
References: <20020430151126.Q16831@dansat.data-plan.com> <20020430183429.33340.qmail@web10005.mail.yahoo.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
User-Agent: Mutt/1.2.5i
In-Reply-To: <20020430183429.33340.qmail@web10005.mail.yahoo.com>; from calinm@yahoo.com on Tue, Apr 30, 2002 at 11:34:29AM -0700
Status: RO
Content-Length: 3111
Lines: 111

Thanks. I'll take a look when I get to DBD::Oracle again.

I think the last row of that table applies and it doesn't refer to OCIBindObject():
    REF CURSOR variables 
    SQLT_RSET 
    Allocate a statement handle, OCIStmt, and then bind its address
    (OCIStmt **) using the SQLT_RSET datatype.
Note that SQLT_REF isn't the same as SQLT_RSET.

You could always try patching it yourself!

Tim.


On Tue, Apr 30, 2002 at 11:34:29AM -0700, Calin Medianu wrote:
> It says here:
> http://technet.oracle.com/doc/oracle8i_816/appdev.816/a76975/oci05bnd.htm#421007
> 
> that 2 calls are neede to bind a ref , the second is
> to OCIBindObject() which I don't see in  dbdimp.c.
> 
> Could this be a reason?
> 
> Cheers,
> 
> Calin
> 
> --- Tim Bunce <Tim.Bunce@pobox.com> wrote:
> > On Tue, Apr 30, 2002 at 04:04:47PM +0300, Calin
> > Medianu wrote:
> > > Me again with the slow cursors.
> > > 
> > > I modified both queries to only return 10 rows.
> > > I ran a sniffer (ethereal) on the NIC. It is
> > pretty cool, it also decodes TNS.
> > > 
> > > when I am using the SQL, it works like this, there
> > are about 7 packets 
> > > received by my workstation to set up the session,
> > then all 10 rows are in the 
> > > same packet, then there is another packet probably
> > saying goodbye.
> > > 
> > > When I am using the REF cursor, each row comes in
> > it's own TNS packet, that 
> > > is why it is so slow!
> > > 
> > > Any idea how to fix it?
> > 
> > Do a level 9 trace to get a log of the OCI calls and
> > confirm that
> > the fragment I posted is being called (may be
> > helpful to also
> > add an extra print statement into that code since
> > parsing the
> > OCI trace can be painful).
> > 
> > Assuming the code is being called then as far as I
> > can see the code is
> > doing the right thing and it's probably an Oracle
> > OCI issue.
> > 
> > You'd need to talk to Oracle support. No need to
> > mention perl etc.
> > Just talk about your OCI application and provide the
> > OCI call trace.
> > 
> > Let me know what you find out!
> > 
> > Tim.
> > 
> > > thanks a lot,
> > > 
> > > Calin
> > > 
> > > > On Mon, Apr 29, 2002 at 01:18:53PM -0700, Calin
> > Medianu wrote:
> > > > > Hello,
> > > > >
> > > > > I did the following. Wrote a perl script that
> > retreves
> > > > > data via a straight select from the database.
> > Then I
> > > > > wrote a stored procedure returning a ref
> > cursor open
> > > > > on the same select statement and retrieved the
> > data as
> > > > > well. Using the REF CURSOR/ sotred procedure
> > was about
> > > > > 3 time slower, that is 40 seconds instead of
> > around
> > > > > 10.
> > > > >
> > > > > Is this normal? Is this a problem with oracle
> > or with
> > > > > DBD::Oracle?
> > > >
> > > > DBD::Oracle. It probably isn't setting up a row
> > cache for the ref cursor.
> > > >
> > > > Get a level 3 trace and look for the
> > "dbd_describe'd" line for the
> > > > ref cursor.
> > > >
> > > > Tim.
> 
> 
> __________________________________________________
> Do You Yahoo!?
> Yahoo! Health - your guide to health and wellness
> http://health.yahoo.com

