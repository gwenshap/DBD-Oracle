From SRS0=JbZc=U3=lincolnbaxter.com=lab@bounce2.pobox.com  Tue Jun 21 05:02:19 2005
Return-Path: <SRS0=JbZc=U3=lincolnbaxter.com=lab@bounce2.pobox.com>
X-Original-To: timbo@localhost
Delivered-To: timbo@localhost.data-plan.com
Received: from localhost (localhost [127.0.0.1])
	by timac.data-plan.com (Postfix) with ESMTP id B016F2A3D98
	for <timbo@localhost>; Tue, 21 Jun 2005 05:02:19 +0100 (IST)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-6.2.5)
	for timbo@localhost (single-drop); Tue, 21 Jun 2005 05:02:19 +0100 (IST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1DkYXK-0003m5-Mr;
	Tue, 21 Jun 2005 02:30:50 +0000
Received: from [194.217.242.223] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1DkYXK-0003m5-Mr
	for pobox@data-plan.com; Tue, 21 Jun 2005 02:30:50 +0000
Received: from [208.210.124.73] (helo=gold.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1DkYXJ-00006n-QE
	for pobox@data-plan.com; Tue, 21 Jun 2005 02:30:50 +0000
Received: from gold.pobox.com (localhost [127.0.0.1])
	by gold.pobox.com (Postfix) with ESMTP id AF60172691;
	Mon, 20 Jun 2005 22:29:36 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from ms-smtp-04-eri0.southeast.rr.com (ms-smtp-04-lbl.southeast.rr.com [24.25.9.103])
	by gold.pobox.com (Postfix) with ESMTP id A3C1E7272E
	for <Tim.Bunce@pobox.com>; Mon, 20 Jun 2005 22:29:11 -0400 (EDT)
Received: from lincolnbaxter.com (cpe-069-132-010-126.carolina.res.rr.com [69.132.10.126])
	by ms-smtp-04-eri0.southeast.rr.com (8.12.10/8.12.7) with ESMTP id j5L2TIL4001864
	for <Tim.Bunce@pobox.com>; Mon, 20 Jun 2005 22:29:18 -0400 (EDT)
Received: (qmail 5171 invoked from network); 20 Jun 2005 22:29:07 -0400
Received: from lws (192.168.0.25)
  by lws with SMTP; 20 Jun 2005 22:29:07 -0400
Subject: Re: gcc options when building DBD:Oracle
From: "Lincoln A. Baxter" <lab@lincolnbaxter.com>
Reply-To: lab@lincolnbaxter.com
To: jriekenberg@everestkc.net
Cc: Tim Bunce <Tim.Bunce@pobox.com>
In-Reply-To: <b47df84a2d11e.42b6e263@core.everestkc.net>
References: <b47df84a2d11e.42b6e263@core.everestkc.net>
Content-Type: text/plain
Date: Mon, 20 Jun 2005 22:29:07 -0400
Message-Id: <1119320947.17452.484.camel@lws>
Mime-Version: 1.0
X-Mailer: Evolution 2.2.1.1 
Content-Transfer-Encoding: 7bit
X-Virus-Scanned: Symantec AntiVirus Scan Engine
Status: RO
Content-Length: 2011
Lines: 38

Hi Jan,

This looks like something that might be relatively easy to fix in
Makefile.PL.  But I no longer have access to HPUX systems, and never
built DBD-Oracle with gcc on that platform.  I could add your message to
the README.hpux file, but it is becoming less and less necessary to read
this file with newer versions of DBD-Oracle, in which Makefile.PL has
been made much smarter. 

Would you consider sending Tim or me a patch to Makefile.PL that
generates the right $(LD) command (only on HP rp8400, and only for your
version of gcc or later? 

Lincoln

On Mon, 2005-06-20 at 15:36 -0500, jriekenberg@everestkc.net wrote:
> Lincoln,
> 
> I recently built DBD:Oracle on an HP rp8400.  Everything worked as expected until I actually issued the "make" command.  Make proceeded as expected until it reached "MakeMaker dynamic_lib" section.  The gcc line in that section failed with the error in the attached text file.  Apparently gcc was not correctly passing the "+b" option to ld.  Instead, it was attempting to interpret the option itself.  It assumed the "+b" was a filename, and that failed because gcc could not find the file.  I ended up adding the "-Xlinker" option before the "+b" and before the "$(LD_RUN_PATH)" in the line in Makefile.  The line now looks like this:
> 
> $(LD) -Xlinker +b -Xlinker "$(LD_RUN_PATH)"  $(LDDLFLAGS) $(LDFROM) $(OTHERLDFLAGS) -o $@ $(MYEXTLIB) $(PERL_ARCHIVE) $(LDLOADLIBS) $(PERL_ARCHIVE_AFTER) $(EXPORT_LIST)
> 
> Running "make" now works correctly.
> 
> Also, "make test" returned the following error when attempting to build the various tests:
> 
> /usr/lib/dld.sl: Can't shl_load() a library containing Thread Local Storage: /usr/lib/libcl.2
> 
> Setting LD_PRELOAD with "export LD_PRELOAD=/usr/lib/libcl.2" corrected this problem, and "make test" worked correctly.
> 
> 
> I didn't see DBD::Oracle documentation on exactly this, so I'm sending this to you.  You may be aware of these items already.  If so, please disregard this.  
> 
> Jon Riekenberg
> 
> 
> 


