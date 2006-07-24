From timbo  Tue Apr 26 09:19:54 2005
Return-path: <SRS0=ZnA8=TD=wrkhors.com=lembark@bounce2.pobox.com>
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-6.2.5)
	for timbo@localhost (single-drop); Tue, 26 Apr 2005 09:19:54 -0700 (PDT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1DQSgy-0006AU-4c;
	Tue, 26 Apr 2005 16:13:44 +0000
Received: from [194.217.242.72] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1DQSgy-0006AU-4c
	for pobox@data-plan.com; Tue, 26 Apr 2005 16:13:44 +0000
Received: from [207.8.226.2] (helo=kelvin.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1DQSgy-0003uM-1T
	for pobox@data-plan.com; Tue, 26 Apr 2005 16:13:44 +0000
Received: from kelvin.pobox.com (localhost [127.0.0.1])
	by kelvin.pobox.com (Postfix) with ESMTP id 759703B902A;
	Tue, 26 Apr 2005 12:13:43 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from kelvin (localhost [127.0.0.1])
	by kelvin.pobox.com (Postfix) with ESMTP id 80C0A39F279
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Tue, 26 Apr 2005 12:13:42 -0400 (EDT)
Received-SPF: none (kelvin.pobox.com: domain of lembark@wrkhors.com does not designate permitted sender hosts)
X-Pobox-Antispam: dnsbl/blackholes.five-ten-sg.com returned DENY: for 66.246.154.128(mail-out.pilosoft.net)
Received: from mail.pilosoft.net (mail-out.pilosoft.net [66.246.154.128])
	by kelvin.pobox.com (Postfix) with ESMTP id 2ED743AB75B
	for <Tim.Bunce@pobox.com>; Tue, 26 Apr 2005 12:12:30 -0400 (EDT)
Received: from [192.168.1.2] (dsl-69-31-90-94.pilosoft.com [69.31.90.94])
	by mail.pilosoft.net (8.12.8/8.12.8) with ESMTP id j3QGA3u1014203
	for <Tim.Bunce@pobox.com>; Tue, 26 Apr 2005 12:10:03 -0400
Date: Tue, 26 Apr 2005 12:14:22 -0400
From: Steven Lembark <lembark@wrkhors.com>
Reply-To: lembark@wrkhors.com
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Possible glitch in DBD::Oracle-1.48 Makefile.pl
Message-ID: <269F0144DC99100E7C80975F@[192.168.1.2]>
X-Mailer: Mulberry/3.1.3 (Linux/x86)
X-Workhorse: lembark 1.1
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Content-Disposition: inline
X-Virus-Scanned: ClamAV version 0.83, clamav-milter version 0.83 on mail.pilosoft.net
X-Virus-Status: Clean
X-Spam-Status: No, score=0.0 required=5.0 tests=none autolearn=failed version=3.0.2
X-Spam-Level: 0.0
X-Spam-Checker-Version: SpamAssassin 3.0.2 (2004-11-16) on cheeta.pilosoft.net
X-Status: A
Content-Length: 1342
Lines: 36

Linking with OTHERLDFLAGS = -L/opt/oracle/product/9.2/lib/ 
-L/opt/oracle/product/9.2/rdbms/lib/   -lclntsh   `cat 
/opt/oracle/product/9.2/lib/sysliblist` -ldl -lm   [from 'build' rule]

Checking if your kit is complete...
Looks good
Use of uninitialized value in substitution (s///) at Makefile.PL line 1446.
LD_RUN_PATH=/opt/oracle/product/9.2/lib:/opt/oracle/product/9.2/rdbms/lib
Using DBD::Oracle 1.16.


    sub const_loadlibs {
    my $self = shift;
    local($_) = $self->SUPER::const_loadlibs(@_);
    # edit LD_RUN_PATH ...
    my ($ldrp) = m/^LD_RUN_PATH\s*=\s*(.*)/m;
    # remove redundant /lib or /usr/lib as it can cause problems
->  $ldrp =~ s!:(/usr)?/lib$!!;
        # if it's empty then set it manually
        #Lincoln: if pick the right library path
        my $libdir = main::ora_libdir();
        $ldrp ||= "$OH/$libdir:$OH/rdbms/$libdir";
        #print "ldrp=$ldrp\n";

    # stitch it back in
    s/^LD_RUN_PATH\s*=\s*(.*)/LD_RUN_PATH=$ldrp/m;
    my $env = $ENV{LD_RUN_PATH};
    print "Ignoring LD_RUN_PATH='$env' in environment\n" if $env;
    print "LD_RUN_PATH=$ldrp\n";
    return $_;
    }

-- 
Steven Lembark                                       85-09 90th Street
Workhorse Computing                                Woodhaven, NY 11421
lembark@wrkhors.com                                     1 888 359 3508

