From dbi-users-return-21438-Tim.Bunce=pobox.com@perl.org  Mon Jan  5 10:12:58 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i05ACYn1063537
	for <timbo@localhost>; Mon, 5 Jan 2004 10:12:58 GMT
	(envelope-from dbi-users-return-21438-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 05 Jan 2004 10:12:58 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AdQXY-0007a7-IO;
	Mon, 05 Jan 2004 09:18:18 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AdQXY-0007a7-IO
	for pobox@dbi.demon.co.uk; Mon, 05 Jan 2004 08:56:48 +0000
Received: from integer.pobox.com (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id C92F0282F
	for <pobox@dbi.demon.co.uk>; Mon,  5 Jan 2004 03:56:45 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id B344B2B84
	for <Tim.Bunce@pobox.com>; Mon,  5 Jan 2004 03:56:45 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by integer.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Mon,  5 Jan 2004 03:56:45 -0500 (EST)
Received: (qmail 58691 invoked by uid 1005); 5 Jan 2004 08:56:38 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 58674 invoked by uid 76); 5 Jan 2004 08:56:38 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Mon, 05 Jan 2004 00:56:38 -0800
Received: (qmail 17937 invoked by uid 225); 5 Jan 2004 08:56:36 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 17930 invoked by uid 507); 5 Jan 2004 08:56:36 -0000
Received: from stone.sifira.dk (HELO mail.int.sifira.dk) (217.157.24.2) by one.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Mon, 05 Jan 2004 00:56:05 -0800
Received: from ash.int.sifira.dk (ash.int.sifira.dk [192.168.1.7])	by mail.int.sifira.dk (Postfix) with ESMTP	id F127674F58; Mon,  5 Jan 2004 09:55:58 +0100 (MET)
Sender: kn@sifira.dk
To: "Anniballi, Fran" <fran.anniballi@hp.com>
Cc: <dbi-users@perl.org>
Subject: Re: Help - multiple Oracle versions
References: <6B003D25ADBDE347B5542AFE6A55B42E03227831@tayexc13.americas.cpqcorp.net>
From: Kristian Nielsen <kn@sifira.dk>
Date: 05 Jan 2004 09:55:59 +0100
In-Reply-To: <6B003D25ADBDE347B5542AFE6A55B42E03227831@tayexc13.americas.cpqcorp.net>
Message-ID: <7sllomsrj4.fsf@ash.int.sifira.dk>
User-Agent: Gnus/5.0808 (Gnus v5.8.8) Emacs/21.2
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-2.5 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_00_01,USER_AGENT,USER_AGENT_GNUS_UA version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 1223
Lines: 40

[Add notes to docs covering what's in this thread]

"Anniballi, Fran" <fran.anniballi@hp.com> writes:

> For option two, if I have two versions of DBD:Oracle, how do I tell
> Perl which one to use?  My scripts just say "/usr/bin/perl" in the
> first line.

Basically, when you compile you use the PREFIX option:

   export ORACLE_HOME=/usr/local/oracle8
   perl Makefile.PL PREFIX=/usr/local/oracle8-perl
   make
   make install

   export ORACLE_HOME=/usr/local/oracle9
   perl Makefile.PL PREFIX=/usr/local/oracle9-perl
   make
   make install

Then before running the perl script you should set the PERLLIB
environment variable to point to the correct location for the proper
version of DBD::Oracle. Alternatively, you could have the perl script
select the proper DBD::Oracle location based on the value of
ORACLE_HOME:

  #! /usr/bin/perl
  BEGIN {
    if($ENV{ORACLE_HOME} =~ /8/) {
      use lib '/usr/local/oracle8-perl/REST/OF/PATH';
    } else {
      use lib '/usr/local/oracle9-perl/REST/OF/PATH';
    }
  }
  use DBI;

This is all from the top of my head; you will need to fiddle a bit to
get the details right (like the correct path etc). Also, I think this
has been covered in greater detail before; you might want to try
searching the archives.

 - Kristian.


From dbi-users-return-21441-Tim.Bunce=pobox.com@perl.org  Mon Jan  5 14:47:30 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i05Ejvo1064760
	for <timbo@localhost>; Mon, 5 Jan 2004 14:47:30 GMT
	(envelope-from dbi-users-return-21441-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Mon, 05 Jan 2004 14:47:30 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AdVCS-0004w0-Is;
	Mon, 05 Jan 2004 13:55:22 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1AdVCS-0004w0-Is
	for pobox@dbi.demon.co.uk; Mon, 05 Jan 2004 13:55:21 +0000
Received: from integer.pobox.com (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 548DE2C87
	for <pobox@dbi.demon.co.uk>; Mon,  5 Jan 2004 08:55:20 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 417692C81
	for <Tim.Bunce@pobox.com>; Mon,  5 Jan 2004 08:55:20 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by integer.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Mon,  5 Jan 2004 08:55:19 -0500 (EST)
Received: (qmail 91728 invoked by uid 1005); 5 Jan 2004 13:55:17 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 48614 invoked by uid 76); 5 Jan 2004 12:24:01 -0000
Delivered-To: dbi-users@perl.org
X-MimeOLE: Produced By Microsoft Exchange V6.0.6487.1
content-class: urn:content-classes:message
MIME-Version: 1.0
Content-Type: text/plain;	charset="iso-8859-1"
Subject: RE: Help - multiple Oracle versions
Date: Mon, 5 Jan 2004 07:23:23 -0500
Message-ID: <6B003D25ADBDE347B5542AFE6A55B42E04537A09@tayexc13.americas.cpqcorp.net>
X-MS-Has-Attach: 
X-MS-TNEF-Correlator: 
Thread-Topic: Help - multiple Oracle versions
Thread-Index: AcPTac0nADA1C8LsTdSTxpcvyeSNCgAHQWGQ
From: "Anniballi, Fran" <fran.anniballi@hp.com>
To: <kn@sifira.dk>
Cc: <dbi-users@perl.org>
X-OriginalArrivalTime: 05 Jan 2004 12:23:24.0525 (UTC) FILETIME=[B6F761D0:01C3D386]
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=0.3 required=7.0 tests=CARRIAGE_RETURNS,QUOTED_EMAIL_TEXT,SPAM_PHRASE_00_01 version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Content-Transfer-Encoding: 8bit
X-MIME-Autoconverted: from quoted-printable to 8bit by dansat.data-plan.com id i05Ejvo1064760
Status: RO
Content-Length: 1465
Lines: 52

Thanks. Looks like this is what I'll need.

-----Original Message-----
From: kn@sifira.dk [mailto:kn@sifira.dk]
Sent: Monday, January 05, 2004 3:56 AM
To: Anniballi, Fran
Cc: dbi-users@perl.org
Subject: Re: Help - multiple Oracle versions


"Anniballi, Fran" <fran.anniballi@hp.com> writes:

> For option two, if I have two versions of DBD:Oracle, how do I tell
> Perl which one to use?  My scripts just say "/usr/bin/perl" in the
> first line.

Basically, when you compile you use the PREFIX option:

   export ORACLE_HOME=/usr/local/oracle8
   perl Makefile.PL PREFIX=/usr/local/oracle8-perl
   make
   make install

   export ORACLE_HOME=/usr/local/oracle9
   perl Makefile.PL PREFIX=/usr/local/oracle9-perl
   make
   make install

Then before running the perl script you should set the PERLLIB
environment variable to point to the correct location for the proper
version of DBD::Oracle. Alternatively, you could have the perl script
select the proper DBD::Oracle location based on the value of
ORACLE_HOME:

  #! /usr/bin/perl
  BEGIN {
    if($ENV{ORACLE_HOME} =~ /8/) {
      use lib '/usr/local/oracle8-perl/REST/OF/PATH';
    } else {
      use lib '/usr/local/oracle9-perl/REST/OF/PATH';
    }
  }
  use DBI;

This is all from the top of my head; you will need to fiddle a bit to
get the details right (like the correct path etc). Also, I think this
has been covered in greater detail before; you might want to try
searching the archives.

 - Kristian.



From dbi-users-return-21449-Tim.Bunce=pobox.com@perl.org  Tue Jan  6 17:00:29 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i06GxrnC075337
	for <timbo@localhost>; Tue, 6 Jan 2004 17:00:29 GMT
	(envelope-from dbi-users-return-21449-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Tue, 06 Jan 2004 17:00:29 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Adu0c-0004RW-9d;
	Tue, 06 Jan 2004 16:24:47 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Adu0c-0004RW-9d
	for pobox@dbi.demon.co.uk; Tue, 06 Jan 2004 16:24:47 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 21A79495C
	for <pobox@dbi.demon.co.uk>; Tue,  6 Jan 2004 11:24:46 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 08B12494B
	for <Tim.Bunce@pobox.com>; Tue,  6 Jan 2004 11:24:46 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by boggle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Tue,  6 Jan 2004 11:24:45 -0500 (EST)
Received: (qmail 25114 invoked by uid 1005); 6 Jan 2004 16:24:42 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 25095 invoked by uid 76); 6 Jan 2004 16:24:42 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Tue, 06 Jan 2004 08:24:42 -0800
Received: (qmail 16535 invoked by uid 225); 6 Jan 2004 16:24:39 -0000
Delivered-To: dbi-users@perl.org
Received: (qmail 16527 invoked by uid 507); 6 Jan 2004 16:24:39 -0000
Received: from mail.cybcon.com (HELO mail.cybcon.com) (216.190.188.5) by one.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Tue, 06 Jan 2004 08:24:08 -0800
Received: from poirot (dsl2-6.cybcon.com [208.186.116.6])	by mail.cybcon.com (8.11.6/8.11.6) with ESMTP id i06GNhn08916;	Tue, 6 Jan 2004 08:23:43 -0800
Subject: RE: Help - multiple Oracle versions
From: Jared Still <jkstill@cybcon.com>
To: "Anniballi, Fran" <fran.anniballi@hp.com>
Cc: DBI List <dbi-users@perl.org>
In-Reply-To: 	<6B003D25ADBDE347B5542AFE6A55B42E03227831@tayexc13.americas.cpqcorp.net>
References: 	<6B003D25ADBDE347B5542AFE6A55B42E03227831@tayexc13.americas.cpqcorp.net>
Content-Type: text/plain
Content-Transfer-Encoding: 7bit
X-Mailer: Ximian Evolution 1.0.8 (1.0.8-11) 
Date: 06 Jan 2004 08:25:59 -0800
Message-Id: <1073406359.324.244.camel@poirot.jks.com>
Mime-Version: 1.0
X-CyberConnectics-MailScanner2-Information: Spam/Virus Scanned at CyberConnectics
X-CyberConnectics-MailScanner2: Found to be clean
X-CyberConnectics-MailScanner2-SpamCheck: 
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=-0.2 required=7.0 tests=CARRIAGE_RETURNS,IN_REP_TO,QUOTED_EMAIL_TEXT,REFERENCES,SPAM_PHRASE_05_08,SUPERLONG_LINE version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
Content-Length: 4050
Lines: 102

I read quickly through this thread, so my apologies if someone
already pointed this out.

It doesn't matter which version of Oracle you compiled DBD with,
you can connect to all your 8i/9i databases on any platform with it.

Assume you compiled with 9i libs, and you can connect to 9i db's with
no problem, but are unable to connect to 8i, getting the error you
mentioned previously.

It appears that you are changing your Oracle environment via the 
oraenv shell script to change your ORACLE_HOME to the 8i version 
of Oracle.

If so, stop doing that.  Just leave your environment at 9i, and
connect to your 8i database.  It will be fine. This is the way
my linux server is setup, and DBD is used to connect to Oracle
versions 7.3, 8.1.6, 8.1.7 and 9.2.0 every day.

At our site DBD is compiled with 8i libs so that we can still
connect to the version 7 databases.  If you compile with 9i libs,
you will be unable to connect to version 7 databases.

HTH

Jared


On Sun, 2004-01-04 at 05:12, Anniballi, Fran wrote:
> This is all done on one UNIX box.
> 
> If I try option one, it doesn't work. I can't access an oracle8 instance with oracle9 sqlplus (or the other way around).  That is the real problem.  Since I can't do this I have to reassign the pointers before I access it.  I can do this fine with sqlplus but with dbi/dbd I have to compile with one or the other.
> 
> For option two, if I have two versions of DBD:Oracle, how do I tell Perl which one to use?  My scripts just say "/usr/bin/perl" in the first line.
> 
> -----Original Message-----
> From: kn@sifira.dk [mailto:kn@sifira.dk]
> Sent: Saturday, January 03, 2004 1:04 PM
> To: dbi-users@perl.org
> Cc: Anniballi, Fran
> Subject: Re: Help - multiple Oracle versions
> 
> 
> "Anniballi, Fran" <fran.anniballi@hp.com> writes:
> 
> > As soon as I recompile the same DBI/DBD with it pointing to Oracle 9
> > environment (libraries), it doesn't work.  It is looking for Oracle9
> > library files and I obviously don't have it pointing to oracle9
> > libraries when I access an Oracle 8 instance.  Oracle 9 is not
> > compatible with Oracle 8 so I have to redirect the environment
> > variables at run time.
> 
> It sounds like you are confusing the Oracle client version and the
> Oracle server version.
> 
> Eg. if you set ORACLE_HOME to /usr/local/oracle8 (or whatever) and use
> /usr/local/oracle8/bin/sqlplus you are using the Oracle 8 client, while
> if you set it to /usr/local/oracle9 and call
> /usr/local/oracle9/bin/sqlplus, you are using the Oracle 9 client.
> 
> Which Oracle instance you access is selected by the connection string;
> for example "sqlplus scott/tiger@DB8" might access the Oracle 8
> instance, and "scott/tiger@DB9" might access the Oracle 9 instance.
> 
> What people are telling you is that you can choose client version
> independently of the server version. For example, it is possible to set
> ORACLE_HOME to /usr/local/oracle9 and call
> 
>     /usr/local/oracle9/bin/sqlplus scott/tiger@DB8
> 
> to access the Oracle 8 instance with the Oracle 9 client. This of course
> requires that the definition for DB8 is present in the file
> /usr/local/oracle-9.2/network/admin/tnsnames.ora.
> 
> So you should either
> 
> 1. Use only the Oracle 9 client, not change ORACLE_HOME, and access both
>    instances with Oracle 9 sqlplus and DBD::Oracle compiled against
>    Oracle 9 libraries.
> 
> or
> 
> 2. Compile DBD::Oracle twice (once against Oracle 8 libraries, once
>    against Oracle 9 libraries, just as you have two versions of sqlplus)
>    and use each one with the proper ORACLE_HOME setting.
> 
> My guess is that you will find possibility 1. the easiest.
> 
> > The tnsnames.ora are all set.  I did what you said already.  
> > 
> > Example: DBI/DBD will work fine if I compile the DBI/DBD pointing to
> > Oracle 8 environment(libraries) and access an Oracle 8 instance.  I
> > didn't have to change tnsnames.ora
> 
> Yes you do: You need to have BOTH Oracle instances defined in EACH
> tnsnames.ora.
> 
> Hope this helps,
> 
>  - Kristian.



From andy@andyh.co.uk  Wed Jan  7 07:31:57 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i077VPn8081048
	for <timbo@localhost>; Wed, 7 Jan 2004 07:31:57 GMT
	(envelope-from andy@andyh.co.uk)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 07 Jan 2004 07:31:57 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1Ae0Yb-0002lT-IA;
	Tue, 06 Jan 2004 23:24:17 +0000
Received: from [208.58.1.194] (helo=integer.pobox.com)
	by punt-3.mail.demon.net with esmtp id 1Ae0Yb-0002lT-IA
	for pobox@dbi.demon.co.uk; Tue, 06 Jan 2004 23:24:17 +0000
Received: from integer.pobox.com (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id 00D7C3C15
	for <pobox@dbi.demon.co.uk>; Tue,  6 Jan 2004 18:24:16 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by integer.pobox.com (Postfix) with ESMTP id CB5813BEA
	for <Tim.Bunce@pobox.com>; Tue,  6 Jan 2004 18:24:16 -0500 (EST)
Received: from mta03-svc.ntlworld.com (mta03-svc.ntlworld.com [62.253.162.43])
	by integer.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Tue,  6 Jan 2004 18:24:16 -0500 (EST)
Received: from excession ([80.2.244.47]) by mta03-svc.ntlworld.com
          (InterMail vM.4.01.03.37 201-229-121-137-20020806) with SMTP
          id <20040106232403.NEKJ9852.mta03-svc.ntlworld.com@excession>;
          Tue, 6 Jan 2004 23:24:03 +0000
Message-ID: <00bd01c3d4ac$e5713190$6564a8c0@excession>
From: "Andy Hassall" <andy@andyh.co.uk>
To: "Eric Lenio" <dbi-users@lenio.net>, "Tim Bunce" <Tim.Bunce@pobox.com>
Cc: <dbi-users@perl.org>
References: <20040102143310.GC27273@lenio.net> <20040104204914.GB60357@dansat.data-plan.com> <20040105123653.GA31473@lenio.net> <20040105223121.GG66760@dansat.data-plan.com> <20040106222634.GG11531@lenio.net> <20040106223845.GE78360@dansat.data-plan.com> <20040106225722.GI11531@lenio.net>
Subject: Re: DBI primary_key tests fail: oracle 8
Date: Tue, 6 Jan 2004 23:29:14 -0000
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-8859-1"
Content-Transfer-Encoding: 7bit
X-Priority: 3
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook Express 6.00.2800.1158
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2800.1165
Status: RO
X-Status: A
Content-Length: 1692
Lines: 43

Eric Lenio wrote:
> OK Tim. One other note -- after reading through oracle docs, I think
> you might want to substitute 'session_user' for 'current_schema' in
> 'select sys_context(...)'.  The definition of session_user is
> "returns the database
> user name by which the current user is authenticated" while
> current_schema is "returns the name of the default schema being used
> in the current session".
> Maybe it doesn't matter, I'm not an oracle guru by any stretch of the
> imagination.

There's several usernames in the USERENV context:

CURRENT_SCHEMA

The schema/user used for unqualified object name resolution; by default the
user you logged in as, but alterable with 'alter session set
current_schema=x'. Useful for avoiding having to maintain loads of synonyms.

CURRENT_USER

The user you're currently authenticated as. Doesn't change in SQL and
anonymous PL/SQL, but changes within definer-rights PL/SQL stored procedures
to the owner of the stored procedure, since stored procs by default run with
the privileges of the owner, not the invoker.

SESSION_USER

Who you originally logged in as, and never changes (but see below). Looks
like the appropriate one to use.

PROXY_USER

I don't think DBD::Oracle supports proxy authentication so don't need to
worry about that one yet. Possibly a bit of a grey area if it does support
it in the future, since this would hold the username in the DSN, but it'd
reauthenticate and change the SESSION_USER on connect (which would probably
have to be specified as an attribute to the $dbh).

-- 
Andy Hassall (andy@andyh.co.uk) icq(5747695) (http://www.andyh.co.uk)
Space: disk usage analysis tool (http://www.andyhsoftware.co.uk/space)


