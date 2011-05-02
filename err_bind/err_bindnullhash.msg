From dbi-users-return-12580-Tim.Bunce=pobox.com@perl.org  Thu Jul 11 17:49:35 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g6BGnYH11008
	for <timbo@localhost>; Thu, 11 Jul 2002 17:49:34 +0100 (BST)
	(envelope-from dbi-users-return-12580-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.59]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 11 Jul 2002 17:49:34 +0100 (BST)
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1026401921:10:09249:41; Thu, 11 Jul 2002 15:38:41 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-1.mail.demon.net
           id aa1124337; 11 Jul 2002 15:38 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id B567C2BF65
	for <Tim.Bunce@data-plan.com>; Thu, 11 Jul 2002 11:38:05 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (onion.valueclick.com [64.70.54.95])
	by dolly1.pobox.com (Postfix) with SMTP id 347792BF62
	for <Tim.Bunce@pobox.com>; Thu, 11 Jul 2002 11:38:05 -0400 (EDT)
Received: (qmail 95914 invoked by uid 1005); 11 Jul 2002 15:38:04 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 95896 invoked by uid 76); 11 Jul 2002 15:38:04 -0000
Received: from ironmail1.cc.lehigh.edu (HELO ironmail1.cc.lehigh.edu) (128.180.39.26)
  by onion.perl.org (qpsmtpd/0.07b) with SMTP; Thu Jul 11 15:38:04 2002 -0000
Received: from  ([128.180.39.20])
	by ironmail1.cc.lehigh.edu with ESMTP with TLS;
	Thu, 11 Jul 2002 11:35:06 -0400 (EDT)
Received: from lawrencework (pc-lfn0.dept.Lehigh.EDU [128.180.52.51])
	by rain.CC.Lehigh.EDU (8.12.4/8.12.4) with SMTP id g6BFZ6rr022463
	for <dbi-users@perl.org>; Thu, 11 Jul 2002 11:35:06 -0400
Message-ID: <0a0401c228f0$93feda10$3334b480@lawrencework>
From: "Phil R Lawrence" <prlawrence@Lehigh.EDU>
To: <dbi-users@perl.org>
References: <083b01c22824$70357340$3334b480@lawrencework> <20020711140937.A568@dansat.data-plan.com>
Subject: Re: error msg suggestion
Date: Thu, 11 Jul 2002 11:35:20 -0400
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-8859-1"
Content-Transfer-Encoding: 7bit
X-Priority: 3
X-MSMail-Priority: Normal
X-Mailer: Microsoft Outlook Express 6.00.2600.0000
X-MimeOLE: Produced By Microsoft MimeOLE V6.00.2600.0000
Status: RO
X-Status: A
Content-Length: 636
Lines: 21

Tim Bunce wrote:
> Binding an undef should work and be treated as a NULL.
>
> Probably a bug in your code or the driver. But you didn't
> say which driver.

Hmmm.  quite right, undefs do bind as NULL.  However, in this case I am
binding $hash{non-existent-key}, which autoinstantiates to an undef, and looks
like this in the trace:
  undef (magic-sg:y)

Of course it was my dumb fault for having the wrong key for lookup, but
nonetheless, perhaps this should work the same as a normal undef.

# $DBI::VERSION = "1.14";
# $DBD::ODBC::VERSION = '0.28';
$DSN = 'driver=Microsoft Access Driver (*.mdb);dbq=StudyManager.mdb';

Thanks,
Phil


