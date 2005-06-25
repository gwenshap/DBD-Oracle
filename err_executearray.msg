From kn@sifira.dk  Mon Mar  1 07:12:20 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i217CIwY019357
	for <timbo@localhost>; Mon, 1 Mar 2004 07:12:20 GMT
	(envelope-from kn@sifira.dk)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 01 Mar 2004 07:12:20 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AxXyq-00025R-43;
	Sun, 29 Feb 2004 20:56:08 +0000
Received: from [194.217.242.71] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1AxXyq-00025R-43
	for pobox@dbi.demon.co.uk; Sun, 29 Feb 2004 20:56:08 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1AxXyp-0007In-Tg
	for pobox@dbi.demon.co.uk; Sun, 29 Feb 2004 20:56:08 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 082DD53C0A
	for <pobox@dbi.demon.co.uk>; Sun, 29 Feb 2004 15:56:07 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 7412553CFB
	for <Tim.Bunce@pobox.com>; Sun, 29 Feb 2004 15:56:06 -0500 (EST)
Received: from mail.int.sifira.dk (stone.sifira.dk [217.157.24.2])
	by boggle.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Sun, 29 Feb 2004 15:56:03 -0500 (EST)
Received: from ash.int.sifira.dk (ash.int.sifira.dk [192.168.1.7])
	by mail.int.sifira.dk (Postfix) with ESMTP id 1C16974F58
	for <Tim.Bunce@pobox.com>; Sun, 29 Feb 2004 21:55:36 +0100 (MET)
Sender: kn@sifira.dk
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: Theory/Algorithm question
References: <48FB76BF31A47C4B9893827DEDF7DF2A03A08CF7@sacexch01.lan.towerrecords.com>
	<7sfzjdrkv2.fsf@ash.int.sifira.dk>
	<20030905085909.GR12308@dansat.data-plan.com>
	<7ssmnbr44t.fsf@ash.int.sifira.dk>
	<20040228153840.GA9857@dansat.data-plan.com>
From: Kristian Nielsen <kn@sifira.dk>
Date: 29 Feb 2004 21:56:00 +0100
In-Reply-To: <20040228153840.GA9857@dansat.data-plan.com>
Message-ID: <7sd67xk3kv.fsf@ash.int.sifira.dk>
User-Agent: Gnus/5.0808 (Gnus v5.8.8) Emacs/21.2
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Status: RO
Content-Length: 3630
Lines: 78

Hi Tim,

Tim Bunce <Tim.Bunce@pobox.com> writes:

> Where did we get to with this?

> > Ok, I will merge it into the new DBD::Oracle when that is out. It really
> > needs to be made to fit better into the execute_for_fetch() and stuff in
> > the new DBI, and I will be happy to modify it to whatever preferences

What I have is a patch for DBD::Oracle 1.14. This patch contains its own
implementation of execute_array(), based on the one in DBI 1.30.

The problem with this is of course that DBD::Oracle should not implement
execute_array itself. The way I understand it is that currently drivers
are supposed to implement execute_for_fetch(), and DBI will use that to
implement the higher-level execute_array() functionality. I see three
possibilities:

1. As you may remember, the count of bind values must be known up-front
before calling into OCI because of OCI limitations. So to switch to the
execute_for_fetch() approach DBD::Oracle must buffer bind tuples in
chunks that are passed to OCI individually. This introduces the annoying
requirement to think about the chunk size. It also introduces some
inefficiencies in the array->tuple_fetch_sub->array conversion. However
if this is what you prefer it would be simple for me to adapt the patch.

2. A better way might be to add an optional third parameter to
execute_for_fetch(): the number of bind tuples. If this parameter is
supplied, DBD::Oracle should be able to implement execute_for_fetch()
without buffering in chunks; this would be utilised by DBI in
execute_array() by passing the third parameter in the cases where an
array is supplied by the programmer. If the count parameter is not
supplied, DBD::Oracle would fall-back to buffering in chunks. The
disadvantage of this is that I would probably have to do some work to
adapt the patch to implement this, but I would be willing to take a shot
if you feel this is the best solution (I think it probably is).

3. The final option would be for DBI to be extended so that it could
somehow detect both native array execute and native execute_for_fetch()
in the driver. It would thus detect that DBD::Oracle supports array
execute directly, but not execute_for_fetch(). DBI would then implement
the bind_param_array() version of execute_array() using the DBD::Oracle
array exec functionality, but would emulate execute_for_fetch() by
buffering tuples. Another driver might implement only execute_for_fetch(),
and DBI would emulate bind_param_array() using that (as it currently
does).

So I would like to hear your opinion on which approach to settle on. If
you have no strong opinions I guess we should go for method 1 since it
needs no changes to DBI and requires the least amount of work for me...


A couple of other issues:

I think there should be added to DBI an easy way to supply a row-wise
array of bind tuples to execute_array(). In my patch I implemented this
with an ArrayTuple attribute for execute_array().

There is also the issue that this will only work for Oracle >= 8.1.5.
Any thoughts on the need to fall back to default DBI behaviour for early
Oracle 8.x.y (this would require detecting server version)? And what
about OCI 7, is support for that going out?

Currently this doesn't work for returning results. I will want to add
that later; while SELECT is maybe not so useful, it will be needed for
stuff like

  INSERT INTO mytable(a,b) VALUES(mysequence.nextval, ?) RETURNING a

Maybe there will be some issues here for the interface to DBI similar to
the issues with drivers permitting multiple result sets?

 - Kristian.

-- 
Kristian Nielsen   kn@sifira.dk
Development Manager, Sifira A/S


