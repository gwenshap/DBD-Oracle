From SRS0=8E1j=QQ=perl.org=dbi-users-return-25638-Tim.Bunce=pobox.com@bounce2.pobox.com  Wed Feb  2 10:11:05 2005
Received: from localhost (localhost [IPv6:::1])
	by dansat.data-plan.com (8.13.1/8.13.1) with ESMTP id j12AAUZ6055956
	for <timbo@localhost>; Wed, 2 Feb 2005 10:11:05 GMT
	(envelope-from SRS0=8E1j=QQ=perl.org=dbi-users-return-25638-Tim.Bunce=pobox.com@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-6.2.5)
	for timbo@localhost (single-drop); Wed, 02 Feb 2005 10:11:05 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CwGaQ-0002Bn-H6;
	Wed, 02 Feb 2005 09:14:10 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CwGaQ-0002Bn-H6
	for pobox@data-plan.com; Wed, 02 Feb 2005 09:14:10 +0000
Received: from [207.8.226.2] (helo=kelvin.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1CwGaP-00042G-Vb
	for pobox@data-plan.com; Wed, 02 Feb 2005 09:14:10 +0000
Received: from kelvin.pobox.com (localhost [127.0.0.1])
	by kelvin.pobox.com (Postfix) with ESMTP id 9C3FB1E3946;
	Wed,  2 Feb 2005 04:14:09 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from kelvin (localhost [127.0.0.1])
	by kelvin.pobox.com (Postfix) with ESMTP id 879981E3958
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed,  2 Feb 2005 04:14:09 -0500 (EST)
Received-SPF: pass (kelvin.pobox.com: domain of dbi-users-return-25638-Tim.Bunce=pobox.com@perl.org designates 63.251.223.186 as permitted sender)
X-SPF-Guess: pass (seems reasonable for dbi-users-return-25638-Tim.Bunce=pobox.com@perl.org to mail through 63.251.223.186)
X-Pobox-Antispam: dnsbl/blackholes.five-ten-sg.com returned DENY: for 63.251.223.186(x6.develooper.com)
Received: from lists.develooper.com (x6.develooper.com [63.251.223.186])
	by kelvin.pobox.com (Postfix) with SMTP id D0B001E3946
	for <Tim.Bunce@pobox.com>; Wed,  2 Feb 2005 04:14:08 -0500 (EST)
Received: (qmail 7188 invoked by uid 514); 2 Feb 2005 09:14:05 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
List-Id: <dbi-users.perl.org>
Delivered-To: mailing list dbi-users@perl.org
Delivered-To: moderator for dbi-users@perl.org
Received: (qmail 2531 invoked from network); 2 Feb 2005 04:10:16 -0000
Delivered-To: dbi-users@perl.org
X-Spam-Status: No, hits=-2.6 required=8.0
	tests=BAYES_00,NO_REAL_NAME
X-Spam-Check-By: la.mx.develooper.com
Received-SPF: pass (x1.develooper.com: local policy)
From: snisim@sankyo.co.jp
X-Authentication-Warning: mailgw.shina.sankyo.co.jp: iscan owned process doing -bs
X-MimeOLE: Produced By Microsoft Exchange V6.5.6944.0
Content-class: urn:content-classes:message
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-2022-jp"
Content-Transfer-Encoding: 7bit
Subject: Making DBD::Oracle with Instant Client 10.1.0.3
Date: Wed, 2 Feb 2005 13:09:58 +0900
Message-ID: <7C6FBEDC782B5642BEAF9C9FDF3F431D83CBE9@EVS001.sankyo.co.jp>
X-MS-Has-Attach: 
X-MS-TNEF-Correlator: 
Thread-Topic: Making DBD::Oracle with Instant Client 10.1.0.3
Thread-Index: AcUI3Q64h9ykph8RSl6pF0OpBbTqJA==
To: <dbi-users@perl.org>
X-OriginalArrivalTime: 02 Feb 2005 04:09:59.0005 (UTC) FILETIME=[0F7508D0:01C508DD]
Status: RO
X-Status: A
Content-Length: 1692
Lines: 44

Hi all,

Thanks to the devel package, I've got succeeded in making DBD::Oracle
with the Oracle Instant Client 10.1.0.3, no *.mk files, in my linux box.
My recipe is:

1) install both basic- and devel-10.1.0.3 rpm packages
2) export ORALCE_HOME="/usr/lib/oracle/10.1.0.3/client"
3) export LD_LIBRARY_PATH="$ORACLE_HOME/lib:$LD_LIBRARY_PATH"
4) modify the Makefile.PL file to bypass the find_headers() routine and
   to pass a correct -I flag to cc (the attached dirty patch is FYI)
5) execute the Makefile.PL * with the -l option *, perl Makefile.PL -l
6) make && make test && make install
#  I got many errors in t/30long.t (retrieving blobs ?)
#  but it seems to work fairly.

I hope this could help those who are annoyed with the "Unable to locate an
oracle.mk,..." error.

Happy DBing,

Satoshi

--- Makefile.PL.orig	2004-10-22 18:07:04.000000000 +0900
+++ Makefile.PL	2005-02-02 12:39:56.703125000 +0900
@@ -276,7 +276,7 @@
     print "Oracle sysliblist: $syslibs\n";
     my $libdir = ora_libdir();
     $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g" };
-    my @h_dirs = find_headers();
+#    my @h_dirs = find_headers();
     if ($client_version_full =~ /^8.0.6/ && $os eq 'hpux') {
 	$linkwith_msg = "-lextp -l$lib.";
 	$opts{LIBS} = [ "-L$OH/$libdir -lextp -l$lib $syslibs" ];
@@ -286,7 +286,8 @@
 	$linkwith_msg = "-l$lib.";
 	$opts{LIBS} = [ "-L$OH/$libdir -l$lib $syslibs" ];
     }
-    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
+#    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
+    my $inc = "-I/usr/include/oracle/10.1.0.3/client";
     $opts{INC}  = "$inc -I$dbi_arch_dir";
 }
 else {	# --- trawl the guts of Oracle's make files looking the how it wants to link

From SRS0=Kn57=QR=sankyo.co.jp=snisim@bounce2.pobox.com  Thu Feb  3 08:10:48 2005
Received: from localhost (localhost [IPv6:::1])
	by dansat.data-plan.com (8.13.1/8.13.1) with ESMTP id j138AMOi093146
	for <timbo@localhost>; Thu, 3 Feb 2005 08:10:48 GMT
	(envelope-from SRS0=Kn57=QR=sankyo.co.jp=snisim@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-6.2.5)
	for timbo@localhost (single-drop); Thu, 03 Feb 2005 08:10:48 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1CwboD-0005ug-LV;
	Thu, 03 Feb 2005 07:53:49 +0000
Received: from [194.217.242.223] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1CwboD-0005ug-LV
	for pobox@data-plan.com; Thu, 03 Feb 2005 07:53:49 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1CwboD-0000Wn-82
	for pobox@data-plan.com; Thu, 03 Feb 2005 07:53:49 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 70999102D9F;
	Thu,  3 Feb 2005 02:53:48 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from boggle (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 5F45E102DCC
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Thu,  3 Feb 2005 02:53:48 -0500 (EST)
X-Pobox-Antispam: Require PTR Record returned DENY: 210.81.52.253 has no PTR record
X-Pobox-Antispam: country/Japan returned DENY: sender address snisim@sankyo.co.jp matches TLD .jp (Japan)
Received-SPF: none (boggle.pobox.com: domain of snisim@sankyo.co.jp does not designate permitted sender hosts)
X-SPF-Guess: pass (seems reasonable for snisim@sankyo.co.jp to mail through 210.81.52.253)
Received: from mailgws.shina.sankyo.co.jp (unknown [210.81.52.253])
	by boggle.pobox.com (Postfix) with ESMTP id A38A5102E20
	for <Tim.Bunce@pobox.com>; Thu,  3 Feb 2005 02:53:46 -0500 (EST)
Received: from es007.sankyo.co.jp (localhost [127.0.0.1])
	by mailgws.shina.sankyo.co.jp (8.9.3p2/3.7W) with ESMTP id LAA15117
	for <Tim.Bunce@pobox.com>; Thu, 3 Feb 2005 11:45:39 +0900 (JST)
From: snisim@sankyo.co.jp
X-Authentication-Warning: mailgws.shina.sankyo.co.jp: iscan owned process doing -bs
Received: from EVS001.sankyo.co.jp ([10.14.121.200]) by es007.sankyo.co.jp with Microsoft SMTPSVC(6.0.3790.0);
	 Thu, 3 Feb 2005 11:45:39 +0900
MIME-Version: 1.0
Content-Type: text/plain;
	charset="iso-2022-jp"
Content-Transfer-Encoding: 7bit
Subject: RE: Making DBD::Oracle with Instant Client 10.1.0.3
Content-class: urn:content-classes:message
X-MimeOLE: Produced By Microsoft Exchange V6.5.6944.0
Date: Thu, 3 Feb 2005 11:46:07 +0900
Message-ID: <7C6FBEDC782B5642BEAF9C9FDF3F431D83CBEC@EVS001.sankyo.co.jp>
X-MS-Has-Attach: 
X-MS-TNEF-Correlator: 
Thread-Topic: Making DBD::Oracle with Instant Client 10.1.0.3
Thread-Index: AcUJEc1pQuIX++g2S8y4AE9WqWRYtQAhsK+Q
To: <Tim.Bunce@pobox.com>
X-OriginalArrivalTime: 03 Feb 2005 02:45:39.0123 (UTC) FILETIME=[71F21030:01C5099A]
Status: RO
Content-Length: 1192
Lines: 36

Hi Tim,

Thank you for your kind reply.

I found my patch will cause a compilation error for the local variable
@h_dirs gets into undefined after commenting out the line 279.  
It should be corrected as following:

--- Makefile.PL.orig	2004-10-22 18:07:04.000000000 +0900
+++ Makefile.PL	2005-02-02 12:39:56.703125000 +0900
@@ -276,7 +276,7 @@
     print "Oracle sysliblist: $syslibs\n";
     my $libdir = ora_libdir();
     $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g" };
-    my @h_dirs = find_headers();
+    my @h_dirs;
     if ($client_version_full =~ /^8.0.6/ && $os eq 'hpux') {
 	$linkwith_msg = "-lextp -l$lib.";
 	$opts{LIBS} = [ "-L$OH/$libdir -lextp -l$lib $syslibs" ];
@@ -286,7 +286,8 @@
 	$linkwith_msg = "-l$lib.";
 	$opts{LIBS} = [ "-L$OH/$libdir -l$lib $syslibs" ];
     }
-    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
+#    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
+    my $inc = "-I/usr/include/oracle/10.1.0.3/client"
     $opts{INC}  = "$inc -I$dbi_arch_dir";
 }
 else {	# --- trawl the guts of Oracle's make files looking the how it wants to link

I'm not a dbi-users member so I can't reply my post... I wonder if you can do it.

Thanks,

Satoshi
 

