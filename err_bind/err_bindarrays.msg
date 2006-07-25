From cturner@redhat.com  Tue Mar 27 06:01:56 2001
Return-Path: <cturner@redhat.com>
Received: from oink by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id GAA19714; Tue, 27 Mar 2001 06:01:56 +0100 (BST)
Received: from 194.217.242.7 by oink with SMTP (PP) id <13771-3@oink>;
          Fri, 27 Mar 1970 06:00:50 +0100
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 985668014:20:27605:3; Tue, 27 Mar 2001 04:40:14 GMT
Received: from host154.207-175-42.redhat.com ([207.175.42.154]) 
          by punt-2.mail.demon.net id ab2125244; 27 Mar 2001 4:39 GMT
Received: from japh.meridian.redhat.com (IDENT:root@japh.meridian.redhat.com [207.175.42.27]) 
          by lacrosse.corp.redhat.com (8.9.3/8.9.3) with ESMTP id XAA32289 
          for <Tim.Bunce@ig.co.uk>; Mon, 26 Mar 2001 23:39:38 -0500
Received: (from cturner@localhost) by japh.meridian.redhat.com (8.11.0/8.11.0) 
          id f2R4bvT12929; Mon, 26 Mar 2001 23:37:57 -0500
Sender: cturner@redhat.com
To: Tim.Bunce@ig.co.uk
Subject: DBD::Oracle and OCI bound arrays
From: Chip Turner <cturner@redhat.com>
Date: 26 Mar 2001 23:37:57 -0500
Message-ID: <vzk66gv25ei.fsf@japh.meridian.redhat.com>
User-Agent: Gnus/5.0808 (Gnus v5.8.8) Emacs/20.7
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Status: A
Content-Length: 980
Lines: 29


Hey Tim,

The need to have true OCI bound arrays for DBD::Oracle has come up,
and it looks like I get the fun job of implementing them.  Basically,
this will allow DBD::Oracle to do something the DCOracle python
library does.  The idea is:

my $sth = $dbh->prepare("INSERT INTO FooBar (c1, c2) VALUES (?, ?)");
my @c1 = 'aa' .. 'zz';
my @c2 = 'aaa' .. 'azz';
$sth->execute(\@c1, \@c2);

In other words, it populates the table with a single execute call,
passing two (or more) equally sized arrays in as references for bound
parameters.  This has the potential to save a good amount of time,
especially for large datasets.

This would pretty much be a proprietary extension for Oracle, though
similar uses could be done in other DBD's.

Just thought I'd let you know what I was intending to do, and to see
if you had any interest in receiving it as a patch after I'm done.

Chip

-- 
Chip Turner                   cturner@redhat.com
                              RHN Web Engineer

From timbo  Tue Mar 27 09:29:48 2001
Return-Path: <timbo>
Received: by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id JAA20809; Tue, 27 Mar 2001 09:29:42 +0100 (BST)
Date: Tue, 27 Mar 2001 09:29:41 +0100
From: Tim Bunce <Tim.Bunce@ig.co.uk>
To: Chip Turner <cturner@redhat.com>
Cc: Tim.Bunce@ig.co.uk, dbi-dev@perl.org
Subject: Re: DBD::Oracle and OCI bound arrays
Message-ID: <20010327092941.D20616@ig.co.uk>
References: <vzk66gv25ei.fsf@japh.meridian.redhat.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.3i
In-Reply-To: <vzk66gv25ei.fsf@japh.meridian.redhat.com>; from Chip Turner on Mon, Mar 26, 2001 at 11:37:57PM -0500
Content-Length: 1570
Lines: 39

On Mon, Mar 26, 2001 at 11:37:57PM -0500, Chip Turner wrote:
> 
> Hey Tim,
> 
> The need to have true OCI bound arrays for DBD::Oracle has come up,
> and it looks like I get the fun job of implementing them.  Basically,
> this will allow DBD::Oracle to do something the DCOracle python
> library does.  The idea is:
> 
> my $sth = $dbh->prepare("INSERT INTO FooBar (c1, c2) VALUES (?, ?)");
> my @c1 = 'aa' .. 'zz';
> my @c2 = 'aaa' .. 'azz';
> $sth->execute(\@c1, \@c2);
> 
> In other words, it populates the table with a single execute call,
> passing two (or more) equally sized arrays in as references for bound
> parameters.  This has the potential to save a good amount of time,
> especially for large datasets.
> 
> This would pretty much be a proprietary extension for Oracle, though
> similar uses could be done in other DBD's.
> 
> Just thought I'd let you know what I was intending to do, and to see
> if you had any interest in receiving it as a patch after I'm done.

I would *urge* you to discuss the implementation with me *before*
you get very far cutting code.

And anyway, I think someone's already done much or all of the work.
Dig around in the dbi-dev archives. If you can't find the discussion
let me know. If you do, then ask them (via the dbi-dev list) what
the status is.

I'm planning to make a DBI release next week and, hopefully, a
DBD::Oracle release the week after to cleare a backlog of patches I
have queued up. After that I'll be looking to add in the work of the
other guy (whose also implemented it for DBD::DB2 and DBD::ODBC).

Tim.

From cturner@redhat.com  Wed Mar 28 02:01:21 2001
Return-Path: <cturner@redhat.com>
Received: from oink by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id CAA27336; Wed, 28 Mar 2001 02:01:21 +0100 (BST)
Received: from 194.217.242.7 by oink with SMTP (PP) id <17151-9@oink>;
          Sat, 28 Mar 1970 01:59:47 +0100
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 985739868:20:27318:0; Wed, 28 Mar 2001 00:37:48 GMT
Received: from host154.207-175-42.redhat.com ([207.175.42.154]) 
          by punt-2.mail.demon.net id ac2119835; 28 Mar 2001 0:37 GMT
Received: from japh.meridian.redhat.com (IDENT:root@japh.meridian.redhat.com [207.175.42.27]) 
          by lacrosse.corp.redhat.com (8.9.3/8.9.3) with ESMTP id TAA10445 
          for <Tim.Bunce@ig.co.uk>; Tue, 27 Mar 2001 19:37:35 -0500
Received: (from cturner@localhost) by japh.meridian.redhat.com (8.11.0/8.11.0) 
          id f2S0ZoJ20115; Tue, 27 Mar 2001 19:35:50 -0500
Sender: cturner@redhat.com
To: Tim Bunce <Tim.Bunce@ig.co.uk>
Subject: Re: DBD::Oracle and OCI bound arrays
References: <vzk66gv25ei.fsf@japh.meridian.redhat.com> <20010327092941.D20616@ig.co.uk>
From: Chip Turner <cturner@redhat.com>
Date: 27 Mar 2001 19:35:50 -0500
In-Reply-To: <20010327092941.D20616@ig.co.uk>
Message-ID: <vzkk85abuhl.fsf@japh.meridian.redhat.com>
User-Agent: Gnus/5.0808 (Gnus v5.8.8) Emacs/20.7
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Status: A
Content-Length: 1495
Lines: 35

Tim Bunce <Tim.Bunce@ig.co.uk> writes:

> I would *urge* you to discuss the implementation with me *before*
> you get very far cutting code.

Unfortunately, it's a little late for this; I've mostly finished the
change (at least, enough for our needs), except for some review and
cleanups.  It seems to work quite well (400 times faster than repeated
looping over a dataset) and passes all of DBD::Oracle's test suite.

> And anyway, I think someone's already done much or all of the work.
> Dig around in the dbi-dev archives. If you can't find the discussion
> let me know. If you do, then ask them (via the dbi-dev list) what
> the status is.

I checked as you suggest, but couldn't find any code, just discussion
of it.  I'll check again, but it didn't seem that the person had put
it anywhere I could get at it.

> I'm planning to make a DBI release next week and, hopefully, a
> DBD::Oracle release the week after to cleare a backlog of patches I
> have queued up. After that I'll be looking to add in the work of the
> other guy (whose also implemented it for DBD::DB2 and DBD::ODBC).

If you would like, the patch will probably be suitable for inclusion
by then, if you want it in by the next release.  Should there be any
problems with it or its implementation, I'd be glad to clean it up if
you have interest in it (if not, that's cool too; we need it soon,
though, either way).

Chip

-- 
Chip Turner                   cturner@redhat.com
                              RHN Web Engineer

From timbo  Wed Mar 28 11:51:58 2001
Return-Path: <timbo>
Received: by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id LAA00444; Wed, 28 Mar 2001 11:51:51 +0100 (BST)
Date: Wed, 28 Mar 2001 11:51:51 +0100
From: Tim Bunce <Tim.Bunce@ig.co.uk>
To: Chip Turner <cturner@redhat.com>
Cc: Tim Bunce <Tim.Bunce@ig.co.uk>
Subject: Re: DBD::Oracle and OCI bound arrays
Message-ID: <20010328115151.D29769@ig.co.uk>
References: <vzk66gv25ei.fsf@japh.meridian.redhat.com> <20010327092941.D20616@ig.co.uk> <vzkk85abuhl.fsf@japh.meridian.redhat.com>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.3i
In-Reply-To: <vzkk85abuhl.fsf@japh.meridian.redhat.com>; from Chip Turner on Tue, Mar 27, 2001 at 07:35:50PM -0500
Content-Length: 1786
Lines: 40

On Tue, Mar 27, 2001 at 07:35:50PM -0500, Chip Turner wrote:
> Tim Bunce <Tim.Bunce@ig.co.uk> writes:
> 
> > I would *urge* you to discuss the implementation with me *before*
> > you get very far cutting code.
> 
> Unfortunately, it's a little late for this; I've mostly finished the
> change (at least, enough for our needs), except for some review and
> cleanups.  It seems to work quite well (400 times faster than repeated
> looping over a dataset) and passes all of DBD::Oracle's test suite.

I trust you've added some more tests for your new functionality!

> > And anyway, I think someone's already done much or all of the work.
> > Dig around in the dbi-dev archives. If you can't find the discussion
> > let me know. If you do, then ask them (via the dbi-dev list) what
> > the status is.
> 
> I checked as you suggest, but couldn't find any code, just discussion
> of it.  I'll check again, but it didn't seem that the person had put
> it anywhere I could get at it.

You could always ask them (CC me).

> > I'm planning to make a DBI release next week and, hopefully, a
> > DBD::Oracle release the week after to cleare a backlog of patches I
> > have queued up. After that I'll be looking to add in the work of the
> > other guy (whose also implemented it for DBD::DB2 and DBD::ODBC).
> 
> If you would like, the patch will probably be suitable for inclusion
> by then, if you want it in by the next release.  Should there be any
> problems with it or its implementation, I'd be glad to clean it up if
> you have interest in it (if not, that's cool too; we need it soon,
> though, either way).

Thanks for the clean-up offer. Send it to me after I make the next
DBD::Oracle release (as a fresh patch over that version please - but
there shouldn't be too many changes).

Tim.

