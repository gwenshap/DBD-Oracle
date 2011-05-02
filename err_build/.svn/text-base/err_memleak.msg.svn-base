From SRS0=Dwok=LW=pallas.eruditorum.org=www-data@bounce2.pobox.com  Wed Sep  1 16:31:37 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i81FRlpg021884
	for <timbo@localhost>; Wed, 1 Sep 2004 16:31:37 +0100 (BST)
	(envelope-from SRS0=Dwok=LW=pallas.eruditorum.org=www-data@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 01 Sep 2004 16:31:37 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1C2WYO-00034m-M1;
	Wed, 01 Sep 2004 14:57:40 +0000
Received: from [194.217.242.72] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1C2WYO-00034m-M1
	for pobox@data-plan.com; Wed, 01 Sep 2004 14:57:40 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1C2WYO-0005CR-FY
	for pobox@data-plan.com; Wed, 01 Sep 2004 14:57:40 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 1C1D6A758C;
	Wed,  1 Sep 2004 10:57:36 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from boggle (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 184C8A7214
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed,  1 Sep 2004 10:57:32 -0400 (EDT)
Received-SPF: fail (boggle.pobox.com: domain of www-data@pallas.eruditorum.org does not designate 63.251.223.170 as permitted sender)
X-SPF-Override: pass (client 63.251.223.170 was found in trusted-forwarder.org, overrides regular SPF fail)
X-Pobox-Antispam: dnsbl/blackholes.five-ten-sg.com returned DENY: for 63.251.223.170(x1.develooper.com)
Received: from x1.develooper.com (x1.develooper.com [63.251.223.170])
	by boggle.pobox.com (Postfix) with SMTP id 7A6C9A7555
	for <Tim.Bunce@pobox.com>; Wed,  1 Sep 2004 10:57:06 -0400 (EDT)
Received: (qmail 5427 invoked by uid 225); 1 Sep 2004 14:57:04 -0000
Delivered-To: TIMB@cpan.org
Received: (qmail 5403 invoked by alias); 1 Sep 2004 14:57:02 -0000
X-Spam-Status: No, hits=-4.9 required=8.0
	tests=BAYES_00
X-Spam-Check-By: la.mx.develooper.com
Received: from pallas.eruditorum.org (HELO pallas.eruditorum.org) (63.251.136.85)
  by la.mx.develooper.com (qpsmtpd/0.27.1) with ESMTP; Wed, 01 Sep 2004 07:56:59 -0700
Received: by pallas.eruditorum.org (Postfix, from userid 33)
	id 1FDD784C0F5; Wed,  1 Sep 2004 10:56:41 -0400 (EDT)
Subject: [cpan #6245] Confirmed memory leak 
From: "Guest via RT" <bug-DBD-Oracle@rt.cpan.org>
Reply-To: bug-DBD-Oracle@rt.cpan.org
In-Reply-To: <rt-6245@cpan>
Message-ID: <rt-6245-22368.6.026866139836@cpan.org>
Precedence: bulk
X-RT-Loop-Prevention: cpan
RT-Ticket: cpan #6245
Managed-by: RT 2.0.15 (http://bestpractical.com/rt/)
RT-Originator: 
Date: Wed,  1 Sep 2004 10:56:41 -0400 (EDT)
To: undisclosed-recipients: ;
Status: RO
Content-Length: 937
Lines: 38


This message about DBD-Oracle was sent to you by guest <> via rt.cpan.org

Full context and any attached attachments can be found at:
<URL: https://rt.cpan.org/Ticket/Display.html?id=6245 >

I Using :
1. SunOS 5.6 Generic_105181-33 sun4u sparc SUNW,Ultra-Enterprise
   Perl 5.005_03
   DBI 1.37
   DBD-Oracle 1.14
   Oracle Release 8.1.5.0.0


2. Linux 2.4.18-17.7.xsmp #1 SMP i686
   Perl 5.6.1
   DBI 1.41
   DBD-Oracle 1.16
   Oracle Release 8.1.6.0.0

II The following code:

use strict;
use DBI;

foreach ( 1 .. 100 ) {
  my $dbh = DBI->connect( 'dbi:Oracle:host=****', '***', '***' );
  $dbh->disconnect();
  sleep(1)
}

III Leak about 4K every 10 seconds

 PID USER     PRI  NI  SIZE  RSS SHARE STAT %CPU %MEM   TIME COMMAND
24927 aldo      15   0  8724 8720  2760 S     1.3  3.4   0:01 perl

 PID USER     PRI  NI  SIZE  RSS SHARE STAT %CPU %MEM   TIME COMMAND
24927 aldo      15   0  8736 8732  2760 S     0.7  3.4   0:01 perl

