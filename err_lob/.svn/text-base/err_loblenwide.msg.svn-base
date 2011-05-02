From nobody@fsck.com  Thu Dec  4 07:36:20 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hB47Y2nE066844
	for <timbo@localhost>; Thu, 4 Dec 2003 07:36:20 GMT
	(envelope-from nobody@fsck.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 04 Dec 2003 07:36:20 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1ARgrA-0005O4-5M;
	Wed, 03 Dec 2003 23:56:32 +0000
Received: from [207.8.214.2] (helo=icicle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1ARgrA-0005O4-5M
	for pobox@dbi.demon.co.uk; Wed, 03 Dec 2003 23:56:32 +0000
Received: from icicle.pobox.com (localhost[127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 314AB9A28F
	for <pobox@dbi.demon.co.uk>; Wed,  3 Dec 2003 18:56:32 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost[127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 188369A287
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 18:56:32 -0500 (EST)
Received: from x1.develooper.com (x1.develooper.com[63.251.223.170])
	by icicle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Wed,  3 Dec 2003 18:56:31 -0500 (EST)
Received: (qmail 3178 invoked by uid 225); 3 Dec 2003 23:56:30 -0000
Delivered-To: TIMB@cpan.org
Received: (qmail 3174 invoked by alias); 3 Dec 2003 23:56:29 -0000
Received: from pallas.eruditorum.org (HELO pallas.eruditorum.org) (63.251.136.85) by la.mx.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Wed, 03 Dec 2003 15:56:18 -0800
Received: by pallas.eruditorum.org (Postfix, from userid 65534)	id 91512114F1; Wed,  3 Dec 2003 18:56:07 -0500 (EST)
Subject: [cpan #4564] Perl DBI bug handling CLOBs 
From: "Jay Turner via RT" <bug-DBI@rt.cpan.org>
Reply-To: bug-DBI@rt.cpan.org
In-Reply-To: <rt-4564@cpan>
Message-ID: <rt-4564-13514.15.0549927817606@cpan.org>
Precedence: bulk
X-RT-Loop-Prevention: cpan
RT-Ticket: cpan #4564
Managed-by: RT 2.0.15 (http://bestpractical.com/rt/)
RT-Originator: J.Turner@mdl.com
To: "AdminCc of cpan Ticket #4564": ;
Date: Wed,  3 Dec 2003 18:56:07 -0500 (EST)
X-Spam-Check-By: la.mx.develooper.com
X-Spam-Status: No, hits=2.1 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,SPAM_PHRASE_01_02,TO_HAS_SPACES,TO_MALFORMED version=2.44
Status: RO
X-Status: A
Content-Length: 1853
Lines: 46


This message about DBI was sent to you by J.Turner@mdl.com <J.Turner@mdl.com> via rt.cpan.org

Full context and any attached attachments can be found at:
<URL: https://rt.cpan.org/Ticket/Display.html?id=4564 >


Date: Fri, 28 Feb 2003 16:55:28 -0800

It has come to my attention that PERL DBI counts on OCILobGetLength
returning BYTES. It returns CHARACTERS instead, which is the count of
variable-width characters. For multi-byte character sets this results
in errors such as:

DBD::Oracle::st fetch failed: ORA-03130: the buffer for the next piece
to be fetched is required (DBD ERROR: OCILobGetLength) at id rmsc01.pl
line 294.

The correct way to read CLOBs is

1) Query the LOB locator for the CSID and CSFRM (character set ID and
form). A character set >= 800 is a mulitbyte character set and csfrm
<> 0 is CLOB.

2) Pass the CSID and CSFRM to OCILobRead with AMT=0 and pass your
buffer address and size.

3) Your callback routine must either be capable of completing the I/O
by allocating additional buffers, or it must notify the caller of
OCILobRead to free the lob locator, since an incomplete read jams the
locator-you can't use it for anything else without finishing the read
(attempts to reuse the locator will result in errors).

Likewise, with OCILobWrite, you have to pass the CSID and CSFRM, with
AMT=0 and the buffer size in bytes. The callback can just say it has
zero bytes and set piece=OCI_LAST_PIECE.

You cannot use the return value of OCILobGetLength as the size of the
data that is being read. The actual size of the data is unknown for
variable-width characters, and the buffer has to be big enough to
accomplish the translation, so you can't just double or triple the
return value from OCILobGetLength (I have seen that approach fail).

You can simulate the effects of a foreign character set by

$ export NLS_LANG=Japanese

