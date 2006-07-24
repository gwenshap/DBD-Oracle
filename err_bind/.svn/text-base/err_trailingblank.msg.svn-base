From dbi-users-bounce@isc.org  Mon May  1 21:12:02 2000
Return-Path: <dbi-users-bounce@isc.org>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id VAA16051; Mon, 1 May 2000 21:12:00 +0100
Received: from finch-punt-12.mail.demon.net by oink with SMTP (PP) 
          id <14295-42@oink>; Fri, 1 May 1970 21:06:08 +0100
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 957208278:10:19133:4; Mon, 01 May 2000 19:11:18 GMT
Received: from pub3.rc.vix.com ([204.152.186.34]) by punt-1.mail.demon.net 
          id aa1123094; 1 May 2000 19:11 GMT
Received: from pub3.rc.vix.com (pub3.rc.vix.com [204.152.186.34]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id B3CCF3FAA;
          Mon, 1 May 2000 12:10:53 -0700 (PDT)
Received: with LISTAR (v0.129a; list dbi-users);
          Mon, 01 May 2000 12:05:42 -0700 (PDT)
Received: from isrv3.isc.org (isrv3.isc.org [204.152.184.87]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id A70763E34 
          for <dbi-users@pub3.rc.vix.com>; Mon, 1 May 2000 12:05:30 -0700 (PDT)
Received: from scotth.emsphone.com (scotth.emsphone.com [199.67.51.179]) 
          by isrv3.isc.org (8.9.1/8.9.1) via ESMTP id MAA25897 
          for <dbi-users@isc.org>;
          Mon, 1 May 2000 12:05:30 -0700 (PDT) env-from (shildret@scotth.emsphone.com)
Received: (from shildret@localhost) by scotth.emsphone.com (8.9.3/8.9.3) 
          id OAA50011 for dbi-users@isc.org;
          Mon, 1 May 2000 14:05:48 -0500 (CDT) (envelope-from shildret)
Message-ID: <XFMail.000501140548.shildret@scotth.emsphone.com>
X-Mailer: XFMail 1.4.0 on FreeBSD
X-Priority: 3 (Normal)
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 8bit
MIME-Version: 1.0
Resent-Date: Thu, 29 Jul 1999 22:07:08 +0100
Resent-Message-Id: <19990729220708.G17723@ig.co.uk>
Resent-From: Tim Bunce <Tim.Bunce@ig.co.uk>
Resent-To: Tim Bunce <Tim.Bunce@ig.co.uk>
Date: Mon, 01 May 2000 14:05:48 -0500 (CDT)
Sender: shildret@scotth.emsphone.com
From: "Scott T. Hildreth" <shildret@scotth.emsphone.com>
To: "dbi-users@isc.org" <dbi-users@isc.org>
Subject: FW: Oracle & Trailing Blanks - possible change in DBD::Oracle
Resent-Sender: shildret@scotth.emsphone.com
Sender: dbi-users-bounce@isc.org
Errors-To: dbi-users-bounce@isc.org
X-original-sender: Tim.Bunce@ig.co.uk
Precedence: bulk
List-unsubscribe: <mailto:dbi-users-request@isc.org?Subject=unsubscribe>
X-List-ID: <dbi-users.isc.org>
List-owner: <mailto:dbi-users-admins@isc.org>
List-post: <mailto:dbi-users@isc.org>
Status: RO
Content-Length: 3885
Lines: 94


Here is the help, I got regarding the trailing spaces.

-----FW: <19990729220708.G17723@ig.co.uk>-----

Date: Thu, 29 Jul 1999 22:07:08 +0100
From: Tim Bunce <Tim.Bunce@ig.co.uk>
To: Tim Bunce <Tim.Bunce@ig.co.uk>
Subject: Oracle & Trailing Blanks - possible change in DBD::Oracle
Cc: "Scott T. HIldreth" <shildret@scotth.emsphone.com>,
 dbi-users@isc.org <dbi-users@isc.org>

    *** From dbi-users -- To unsubscribe, see the end of this message. ***

On Thu, Jul 29, 1999 at 09:49:38PM +0100, Tim Bunce wrote:
>     *** From dbi-users -- To unsubscribe, see the end of this message. ***
> 
> On Thu, Jul 29, 1999 at 09:33:55AM -0500, Scott T. HIldreth wrote:
> > 
> > Hi all, I wonder if someone can let me know if I got this right.
> > I have a key to match which can contain trailing blanks.  The 
> > field in the database is CHAR(18).  If I match the key with 
> > sqlplus, Oracle finds a match, with or without the trailing
> > blank.  When I do an sth->execute( $key ), the key is not 
> > found.  I abstract the key with substr, so the trailing blank
> > is in the key, but no match is found.  Do I need to place qoutes
> > around the value in $key?
> 
> Somewhat hiddedn in the Oraperl.pm docs it says this:
> 
> ---
> B<DBD:> Substitution variables are now bound as type 1 (VARCHAR2)
> and not type 5 (STRING) by default. This can alter the behaviour of
> SQL code which compares a char field with a substitution variable.
> See the String Comparison section in the Datatypes chapter of the
> Oracle OCI manual for more details.
>  
> You can work around this by using DBD::Oracle's ability to specify
> the Oracle type to be used on a per field basis:
>  
>   $char_attrib = { ora_type => 5 }; # 5 = STRING (ala oraperl2.4)
>   $csr = ora_open($dbh, "select foo from bar where x=:1 and y=:2");
>   $csr->bind_param(1, $value_x, $char_attrib);
>   $csr->bind_param(2, $value_y, $char_attrib);
>   ora_bind($csr);  # bind with no parameters since we've done bind_param()'s
> ---
> 
> Ignoring the Oraperl specifics there the key point is to use
> 
>   $csr->bind_param($idx, $value, { ora_type => 5 });
> 
> I'll add something to the DBD::Oracle docs.

[You'll still need to blank-pad the string.]

Looking at this issue again I've discovered that the key issue is that
type 1 strips trailing blanks whilst type 5 doesn't.

I'rather m concerned by this. Since I'm against the DBI changing the
data in any way on principle and since Oraperl used to use type 5
I'm strongly considering changing DBD::Oracle 'back' to using type 5.

This would only affect anyone who relies on placeholders having
trailing blanks stripped off. (I'll provide a way to alter the
default with a single statement and/or env var for anyone affected).

If that's you - speak up now!

Tim.

------------------------------------------------------------------------------
To unsubscribe from this list, please visit: http://www.isc.org/dbi-lists.html
If you are without web access, or if you are having trouble with the web page,
please send mail to dbi-users-request@isc.org with the subject line of
'unsubscribe'.
------------------------------------------------------------------------------


--------------End of forwarded message-------------------------

----------------------------------
E-Mail: Scott T. Hildreth <shildret@scotth.emsphone.com>
Date: 01-May-00
Time: 14:04:41
----------------------------------


------------------------------------------------------------------------------
DBI HOME PAGE AND ARCHIVES: http://www.symbolstone.org/technology/perl/DBI/
To unsubscribe from this list, please visit: http://www.isc.org/dbi-lists.html
If you are without web access, or if you are having trouble with the web page, 
please send mail to dbi-users-request@isc.org with the subject line of:
'unsubscribe'.
------------------------------------------------------------------------------ 

From joshua.horton@mail.tju.edu  Fri May 23 07:43:09 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.6/8.12.6) with ESMTP id h4N6UY7T061880
	for <timbo@localhost>; Fri, 23 May 2003 07:43:09 +0100 (BST)
	(envelope-from joshua.horton@mail.tju.edu)
Received: from pop3.mail.demon.net [194.217.242.58]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 23 May 2003 07:43:09 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1053631164:10:02298:54; Thu, 22 May 2003 19:19:24 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1116141; 22 May 2003 19:19 GMT
Received: from dolly1.pobox.com (localhost [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id BD31E21C13C
	for <Tim.Bunce@data-plan.com>; Thu, 22 May 2003 15:18:30 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from mail.tju.edu (fw-tr16.tju.edu [147.140.233.16])
	by dolly1.pobox.com (Postfix) with ESMTP id 615A521C06D
	for <Tim.Bunce@pobox.com>; Thu, 22 May 2003 15:18:22 -0400 (EDT)
Received: from PCSE447.tjh.tju.edu by mail.tju.edu for Tim.Bunce@pobox.com; Thu, 22 May 2003 15:17:54 -0400
Message-Id: <031301c32096$de68f6f0$2310ae0a@PCSE447>
From: "Joshua Horton" <joshua.horton@mail.tju.edu>
To: <Tim.Bunce@pobox.com>
Subject: Re: :Oracle and Oracle 9.2?
Date: Thu, 22 May 2003 15:18:03 -0400
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-8859-1"
Content-Transfer-Encoding: 7bit
X-Priority: 3
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook Express 5.50.4807.1700
X-MimeOLE: Produced By Microsoft MimeOLE V5.50.4910.0300
Status: RO
X-Status: A
Content-Length: 3511
Lines: 99

Re: :Oracle and Oracle 9.2?

----------------------------------------------------------------------------
----

  a.. From: Tim Bunce
  b.. Subject: Re: :Oracle and Oracle 9.2?
  c.. Date: Tue, 15 Apr 2003 07:36:55 -0700

----------------------------------------------------------------------------
----

I'd appreciate it if other people with Oracle 9.2.x could let me
know if it passed or failed for them and what their exact oracle
version (four digits) and platform (operating system) is.

Thanks.

Tim.

On Fri, Apr 04, 2003 at 01:48:36PM +0200, Smejkal Petr wrote:
> I have the same experience on Linux however on Windows all tests passes
(I'm not
> sure if it is related to different Oracle version - test of windows Perl
against
> Linux Oracle is OK).
>
> Linux Oracle: 9.2.0.2
> Windows Oracle: 9.2.0.1
> DBI: 1.35
> DBD::Oracle: 1.14
>
> -- Petr Smejkal
> -- Business Systems Analyst / Country IT Cz/Sk
> -- +420 284 059 639
>
> > -----Original Message-----
> > From: Tom Malaher [mailto:[EMAIL PROTECTED]
> > Sent: Friday, April 04, 2003 1:35 AM
> > To: [EMAIL PROTECTED]
> > Subject: DBD::Oracle and Oracle 9.2?
> >
> >
> > My sysadmin is trying to install DBD::Oracle on a Solaris box running
> > Oracle 9.2.
> >
> > The ph_type.t test is failing with
> >
> > PERL_DL_NONLAZY=1 ./perl "-MExtUtils::Command::MM" "-e"
> > "test_harness(0, 'blib/lib', 'blib/arch')" t/*.t
> > t/base.......ok
> > t/cursor.....ok
> > t/general....ok
> > t/long.......ok
> > t/meta.......ok
> > t/ph_type....NOK 12 expected 'trailing' but got 'trailing '
> > for VARCHAR2
> > t/ph_type....FAILED test 12
> >         Failed 1/19 tests, 94.74% okay
> > t/plsql......ok
> > t/reauth.....skipped
> >         all skipped: no reason given
> > t/select.....ok
> > Failed Test Stat Wstat Total Fail  Failed  List of Failed
> > --------------------------------------------------------------
> > -----------------
> > t/ph_type.t               19    1   5.26%  12
> > 1 test skipped.
> > Failed 1/9 test scripts, 88.89% okay. 1/314 subtests failed,
> > 99.68% okay.
> > *** Error code 29
> > make: Fatal error: Command failed for target `test_static'
> >
> > Is there a known problem with DBD::Oracle and Oracle 9.x?
> > Has Oracle changed the behavior of trailing spaces in VARCHAR2 fields?
> >
> > I've run the same test script on an oracle 8 installation
> > using DBD::Oracle 1.06 and DBI 1.14, and it works fine (no trailing
> > space is returned).
> >
> > Tom
> >
My config:HP-UX 11.11 (64-bit) on rp5470 2x733 5GB RAMOracle 9.2.0.2.0
Enterprise Edition (64-bit)Perl 5.8.0 custom compiled  with
./Configure -Duse64bitall -Ubincompat5005 -Duselargefiles -Dprefix=/opt/perl
5 ; all other options defaultDBI-1.32 all passed some skippedDBD-Oracle-1.14
:        PERL_DL_NONLAZY=1 /opt/perl5/bin/perl "-MExtUtils::Command::MM"
"-e" "test_harness(0, 'blib/lib', 'blib/arch')"
t/*.tt/base.......okt/cursor.....okt/general....okt/long.......okt/meta.....
..okt/ph_type....ok 11/19 expected 'trailing' but got 'trailing ' for
VARCHAR2t/ph_type....FAILED test 12        Failed 1/19 tests, 94.74%
okayt/plsql......okt/reauth.....skipped        all skipped: no reason
givent/select.....okFailed Test Stat Wstat Total Fail  Failed  List of
Failed----------------------------------------------------------------------
-------------------------------------------------------t/ph_type.t
19    1   5.26%  121 test skipped.Failed 1/9 test scripts, 88.89% okay.
1/314 subtests failed, 99.68% okay.*** Error exit code 2Stop.Thanks,Josh
Horton


From nobody@fsck.com  Tue Dec 30 14:33:50 2003
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id hBUEWNnP026077
	for <timbo@localhost>; Tue, 30 Dec 2003 14:33:50 GMT
	(envelope-from nobody@fsck.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 30 Dec 2003 14:33:50 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AbJwa-0003ua-H6;
	Tue, 30 Dec 2003 13:29:56 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AbJwa-0003ua-H6
	for pobox@dbi.demon.co.uk; Tue, 30 Dec 2003 13:29:56 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 56DAD4C6
	for <pobox@dbi.demon.co.uk>; Tue, 30 Dec 2003 08:29:55 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 3B3564C8
	for <Tim.Bunce@pobox.com>; Tue, 30 Dec 2003 08:29:55 -0500 (EST)
Received: from x1.develooper.com (x1.develooper.com [63.251.223.170])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Tue, 30 Dec 2003 08:29:54 -0500 (EST)
Received: (qmail 10988 invoked by uid 225); 30 Dec 2003 13:29:53 -0000
Delivered-To: TIMB@cpan.org
Received: (qmail 10984 invoked by alias); 30 Dec 2003 13:29:52 -0000
Received: from pallas.eruditorum.org (HELO pallas.eruditorum.org) (63.251.136.85) by la.mx.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Tue, 30 Dec 2003 05:29:41 -0800
Received: by pallas.eruditorum.org (Postfix, from userid 65534)	id 8760D11153; Tue, 30 Dec 2003 08:29:37 -0500 (EST)
Subject: [cpan #4786] Oracle 9.2.0.0 fails a test in ph_types.t 
From: "Guest via RT" <bug-DBD-Oracle@rt.cpan.org>
Reply-To: bug-DBD-Oracle@rt.cpan.org
In-Reply-To: <rt-4786@cpan>
Message-ID: <rt-4786-14188.7.96432210636851@cpan.org>
Precedence: bulk
X-RT-Loop-Prevention: cpan
RT-Ticket: cpan #4786
Managed-by: RT 2.0.15 (http://bestpractical.com/rt/)
RT-Originator: 
To: "AdminCc of cpan Ticket #4786": ;
Date: Tue, 30 Dec 2003 08:29:37 -0500 (EST)
X-Spam-Check-By: la.mx.develooper.com
X-Spam-Status: No, hits=2.1 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,SPAM_PHRASE_01_02,SUPERLONG_LINE,TO_HAS_SPACES,TO_MALFORMED version=2.44
Status: RO
Content-Length: 888
Lines: 11


This message about DBD-Oracle was sent to you by guest <> via rt.cpan.org

Full context and any attached attachments can be found at:
<URL: https://rt.cpan.org/Ticket/Display.html?id=4786 >

Assuming that ORA_OCI() gets set correctly when compiling against 9.2, the attached patch will work. I also tried this in SQL*Plus and was able to insert a trailing space into a VARCHAR2. (I replicated the test in ph_types.t).

I did not test my patch as I installed DBD::Oracle 1.14 by setting the chops_spaces value in %test_info to 0. When I did that, everything installed fine. However, I didn't think that my solution was the best for the module, so I figured ORA_OCI should do the trick.

I'm running Perl5.8.0 for Solaris2.9 going against the full Oracle build for 9.2. (I did not run into this issue, surprisingly, on Redhat9 running Perl 5.8.2, but I built against Oracle 9.1 there ...)

