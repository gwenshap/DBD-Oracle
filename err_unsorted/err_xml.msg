From dbi-users-return-19852-Tim.Bunce=pobox.com@perl.org  Fri Aug 15 14:41:14 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id h7FDe3MA043557
	for <timbo@localhost>; Fri, 15 Aug 2003 14:41:13 +0100 (BST)
	(envelope-from dbi-users-return-19852-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 15 Aug 2003 14:41:13 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 19nc4X-0006LQ-BC;
	Fri, 15 Aug 2003 10:44:41 +0000
Received: from [207.106.49.22] (helo=dolly1.pobox.com)
	by punt-3.mail.demon.net with esmtp id 19nc4X-0006LQ-BC
	for pobox@dbi.demon.co.uk; Fri, 15 Aug 2003 10:44:41 +0000
Received: from dolly1.pobox.com (localhost[127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 16F6B21C13B
	for <pobox@dbi.demon.co.uk>; Fri, 15 Aug 2003 06:44:41 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.develooper.com[63.251.223.166])
	by dolly1.pobox.com (Postfix) with SMTP id 021F121C36F
	for <Tim.Bunce@pobox.com>; Fri, 15 Aug 2003 06:44:40 -0400 (EDT)
Received: (qmail 78180 invoked by uid 1005); 15 Aug 2003 10:44:34 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 71287 invoked by uid 76); 15 Aug 2003 10:32:13 -0000
Delivered-To: dbi-users@perl.org
Received-SPF: unknown (domain of sender andyhassall@yahoo.com does not designate mailers: NXDOMAIN)
Message-ID: <20030815103200.24313.qmail@web9605.mail.yahoo.com>
Date: Fri, 15 Aug 2003 11:32:00 +0100 (BST)
From: =?iso-8859-1?q?Andy=20Hassall?= <andyhassall@yahoo.com>
Reply-To: andy@andyh.co.uk
Subject: Re: ERROR OCIDefineObject call needed but not implemented yet using XMLElement function
To: Susan Cassidy <scassidy@accelrys.com>, dbi-users@perl.org
In-Reply-To: <OFA6CE59F4.31D063CD-ON88256D82.007505EE-88256D82.00758F08@accelrys.com>
MIME-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
X-SMTPD: qpsmtpd/0.27-dev, http://develooper.com/code/qpsmtpd/
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-0.8 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,SPAM_PHRASE_01_02 version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id h7FDe3MA043557
Status: RO
Content-Length: 2299
Lines: 65

 --- Susan Cassidy <scassidy@accelrys.com> wrote: > I am using DBD::Oracle. 
I was on version 1.12, then I installed version 
> 1.14, with the same result.
> 
> This is Oracle 9.2.0.
> 
> I have this select statement that works fine from SQL*Plus:
> 
> select    XMLElement("Sequences",
>       XMLElement("Sequence",
>         XMLATTRIBUTES ( b.local_name AS "ic-acckey",
>                         b.mol_type AS "molecule",
>                         n.seq_name AS "title")))
>      from gcg_bioseq b, gcg_annot_seq_name a, gcg_seq_name n
>       where
>         b.local_name = 'K00306' and
>         b.seq_status = 'D' and
>         b.seq_oid = a.seq_oid and
>         a.seq_name_oid = n.seq_name_oid  and
>         n.name_type = 'LOCUS'
> 
> 
> When I run it via DBI/DBD I get this (trace level 2):
> 
>     DBI 1.32-nothread dispatch trace level set to 2
>     Note: perl is running without the recommended perl -w option
>     -> prepare for DBD::Oracle::db (DBI::db=HASH(0x1b2314)~0x122bec ' 
[snip
> Field 1 has an Oracle type (108) which is not explicitly supported
>     fbh 1: 
>
'XMLELEMENT("SEQUENCES",XMLELEMENT("SEQUENCE",XMLATTRIBUTES(B.LOCAL_NAMEAS"IC-ACCKEY",B.MOL_TYPEAS"MOLECULE",N.SEQ_NAMEAS"TITLE")))'
[snip] 
> Error:  prepare failed
>    at line 56, error: ERROR OCIDefineObject call needed but not 
> implemented yet
> 
> Is there any other workaround for this than wrapping this up in a PL/SQL 
> function?

 Don't rely on the implicit conversion to a string type that is done when
SQL*Plus displays an XMLElement; add .getClobVal() to the end of the
statement to retrieve it as a CLOB rather than the XMLElement object type
(which DBD::Oracle doesn't accept).

 i.e.

select    XMLElement("Sequences",
      XMLElement("Sequence",
        XMLATTRIBUTES ( b.local_name AS "ic-acckey",
                        b.mol_type AS "molecule",
                        n.seq_name AS "title"))).getClobVal()
     from ...

 (or getStringVal() for a VARCHAR2)

=====
-- 
Andy Hassall (andy@andyh.org) icq(5747695) http://www.andyh.co.uk
http://www.andyhsoftware.co.uk/space | disk usage analysis tool

________________________________________________________________________
Want to chat instantly with your online friends?  Get the FREE Yahoo!
Messenger http://uk.messenger.yahoo.com/


