From SRS0=VEIf=LP=genericom.de=pl@bounce2.pobox.com  Wed Aug 25 17:53:58 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7PGpkpQ033405
	for <timbo@localhost>; Wed, 25 Aug 2004 17:53:57 +0100 (BST)
	(envelope-from SRS0=VEIf=LP=genericom.de=pl@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 25 Aug 2004 17:53:57 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1Bzyve-0007kY-Gp;
	Wed, 25 Aug 2004 14:39:10 +0000
Received: from [194.217.242.223] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1Bzyve-0007kY-Gp
	for pobox@data-plan.com; Wed, 25 Aug 2004 14:39:10 +0000
Received: from [208.58.1.198] (helo=lime.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1Bzyvd-0000zb-Lg
	for pobox@data-plan.com; Wed, 25 Aug 2004 14:39:10 +0000
Received: from lime.pobox.com (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id AA6D8B0635;
	Wed, 25 Aug 2004 10:39:08 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from lime (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id 9B2A1B0BB0
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 25 Aug 2004 10:39:08 -0400 (EDT)
Received-SPF: none (lime.pobox.com: domain of pl@genericom.de does not designate permitted sender hosts)
Received: from natnoddy.rzone.de (natnoddy.rzone.de [81.169.145.166])
	by lime.pobox.com (Postfix) with ESMTP id 2AAB1B0635
	for <Tim.Bunce@pobox.com>; Wed, 25 Aug 2004 10:39:06 -0400 (EDT)
Received: from genericom.de (pD95195AC.dip.t-dialin.net [217.81.149.172])
	by post.webmailer.de (8.12.10/8.12.10) with ESMTP id i7PEc05w018990
	for <Tim.Bunce@pobox.com>; Wed, 25 Aug 2004 16:38:01 +0200 (MEST)
Sender: pl@post.webmailer.de
Message-ID: <412CA445.FC2F9EF2@genericom.de>
Date: Wed, 25 Aug 2004 16:37:57 +0200
From: Philipp Lang <pl@genericom.de>
Organization: Genericom Software
X-Mailer: Mozilla 4.77 [en] (X11; U; Linux 2.4.24 i686)
X-Accept-Language: de, en
MIME-Version: 1.0
To: Tim.Bunce@pobox.com
Subject: DBD::Oracle: Freeing a temporary blob
Content-Type: multipart/signed; protocol="application/x-pkcs7-signature"; micalg=sha1; boundary="------------ms4BC2D4519D41A502BB06559C"
Status: RO
X-Status: A
Content-Length: 4985
Lines: 122

This is a cryptographically signed message in MIME format.

--------------ms4BC2D4519D41A502BB06559C
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

Dear Tim,

first, I would really like to thank you for the great work you have done
with your DBI/DBD work. We are using it extensively in several projects
and we are highly pleased.

Unfortunately I have now encountered a problem we need to fix urgently,
since our customer's production is seriously  affected.

We tried for many days to find a solution (google, newsgroups,
trial-and-error...), without luck. So my last chance is to contact you
directly, although I assume you have a lot work yourself.

---

The problem:

Our database contains a stored function "ReadUnitBlob()" that returns a
temporary blob: 

function ReadUnitBlob(UnitID_IN in integer) return blob
is
...
begin
  ...
  dbms_lob.createtemporary(retBlob, false, dbms_lob.call);
  dbms_lob.loadfromfile(retBlob, bfileIn, fileLen);
  ...
  return retBlob;
end;

We call this function in Perl in a big loop to fetch a lot of blobs (~
100000) using something like:
 
my $sth = $DBH->prepare("select ReadUnitBlob(:unitID) from dual", {
ora_auto_lob => 0 });
$sth->bind_param(":unitID", $unitID);
$sth->execute();
my ($loc) = $sth->fetchrow_array();
$sth->finish();
...
while(my $data = $DBH->ora_lob_read($loc, $offset, $chunk_size))
  ...

Although this works, it has a big disadvantage: Oracle does not
automaticaly free the temporary blob, so it shortly runs out of temp.
space. (confirmed with "select * from v$temporary_lobs").

Acording to the Oracle docs this can be we solved by implicitly freeing
the temp. blob, e.g. by calling the PLSQL method
"dbms_lob.freetemporary()". I tried differnt ways to do this with
DBD::Oracle, but never succeeded. I just did not manage to fetch the LOB
locator from the my stored procedure and to pass it to a call of
"dbms_lob.freetemporary()":

my $sth = $dbh->prepare("begin :bloc := ReadUnitBlob(:unitID); end;", {
ora_auto_lob => 0 });
my $bloc;
$sth->bind_param_inout( ":bloc", \$bloc, ORA_BLOB);
$sth->bind_param(":unitID", $unitID);
$sth->execute();

obviously the "ORA_BLOB" type for bind_param_inout() is wrong here ;)

Can you help me??? Do you know a way how to free the temp. blob using
DBD::Oracle (using Oracle::OCI is not possible, since the customer is
strinctly refusing to install it).

Otherwise, would it be possible include an additional DBD::Oracle LOB
Locator Method "ora_lob_freetemporary()" that warps
"OCILobFreeTemporary" ?

Any help is really appreciated!

Greeting from Germany,

  Philipp

--
Dipl. Inf. Philipp Lang                         Genericom Software GmbH
Tel. +49 (0)7031/8739-26                              Tilsiter Str. 4-6
Fax  +49 (0)7031/8739-11                             71065 Sindelfingen
pl@genericom.de                                        www.genericom.de
--------------ms4BC2D4519D41A502BB06559C
Content-Type: application/x-pkcs7-signature; name="smime.p7s"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="smime.p7s"
Content-Description: S/MIME Cryptographic Signature

MIIFLgYJKoZIhvcNAQcCoIIFHzCCBRsCAQExCzAJBgUrDgMCGgUAMAsGCSqGSIb3DQEHAaCC
Aw0wggMJMIICcqADAgECAg4WKgAAAALXCfeUwksXHjANBgkqhkiG9w0BAQQFADCBvDELMAkG
A1UEBhMCREUxEDAOBgNVBAgTB0hhbWJ1cmcxEDAOBgNVBAcTB0hhbWJ1cmcxOjA4BgNVBAoT
MVRDIFRydXN0Q2VudGVyIGZvciBTZWN1cml0eSBpbiBEYXRhIE5ldHdvcmtzIEdtYkgxIjAg
BgNVBAsTGVRDIFRydXN0Q2VudGVyIENsYXNzIDEgQ0ExKTAnBgkqhkiG9w0BCQEWGmNlcnRp
ZmljYXRlQHRydXN0Y2VudGVyLmRlMB4XDTAzMTIwODA5NTQyNFoXDTA1MDEzMDA5NTQyNFow
RDELMAkGA1UEBhMCREUxFTATBgNVBAMTDFBoaWxpcHAgTGFuZzEeMBwGCSqGSIb3DQEJARYP
cGxAZ2VuZXJpY29tLmRlMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAJqCn5ZXevTm3KgAKlKk
tOMzn1utWbcKoyrjuUSUOk9hwKXqjCtlBrNUDfVCtJIFWTU/2diijqormxUCXYr60F8CAwEA
AaOByDCBxTAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIF4DAzBglghkgBhvhCAQgEJhYk
aHR0cDovL3d3dy50cnVzdGNlbnRlci5kZS9ndWlkZWxpbmVzMBEGCWCGSAGG+EIBAQQEAwIF
oDBdBglghkgBhvhCAQMEUBZOaHR0cHM6Ly93d3cudHJ1c3RjZW50ZXIuZGUvY2dpLWJpbi9j
aGVjay1yZXYuY2dpLzE2MkEwMDAwMDAwMkQ3MDlGNzk0QzI0QjE3MUU/MA0GCSqGSIb3DQEB
BAUAA4GBAI4bC7MGQQTY9Cp09FYwPychOQs8yFNKHrqYwFhXOirqVTqwo1wgxuSO5/fYWbcs
neWGio3swv0y+jn7o0gkrr/pHNbbm/YmCMuiGuwciH2y4GU2BOukFFP4Otke5UL9Yc9l13eG
Aoaf9ApqRrckhbhLhjz3+gyUM5XRYpoOZX0LMYIB6TCCAeUCAQEwgc8wgbwxCzAJBgNVBAYT
AkRFMRAwDgYDVQQIEwdIYW1idXJnMRAwDgYDVQQHEwdIYW1idXJnMTowOAYDVQQKEzFUQyBU
cnVzdENlbnRlciBmb3IgU2VjdXJpdHkgaW4gRGF0YSBOZXR3b3JrcyBHbWJIMSIwIAYDVQQL
ExlUQyBUcnVzdENlbnRlciBDbGFzcyAxIENBMSkwJwYJKoZIhvcNAQkBFhpjZXJ0aWZpY2F0
ZUB0cnVzdGNlbnRlci5kZQIOFioAAAAC1wn3lMJLFx4wCQYFKw4DAhoFAKCBsTAYBgkqhkiG
9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0wNDA4MjUxNDM3NThaMCMGCSqG
SIb3DQEJBDEWBBS+u38esQAv19TdNkv4jgxlzsRqSzBSBgkqhkiG9w0BCQ8xRTBDMAoGCCqG
SIb3DQMHMA4GCCqGSIb3DQMCAgIAgDAHBgUrDgMCBzANBggqhkiG9w0DAgIBQDANBggqhkiG
9w0DAgIBKDANBgkqhkiG9w0BAQEFAARAJQgoN5ASnyjnB7bgrv1+V7Cu4ULKe1CkHs0IEZaB
KuJcm98U7kskRyC5g6YNopuJxFbr19K3q5rrJGoUscKjiw==
--------------ms4BC2D4519D41A502BB06559C--


From SRS0=SXka=LP=dansat.data-plan.com=timbo@bounce2.pobox.com  Wed Aug 25 22:47:05 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7PLjxpJ037568
	for <timbo@localhost>; Wed, 25 Aug 2004 22:47:04 +0100 (BST)
	(envelope-from SRS0=SXka=LP=dansat.data-plan.com=timbo@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Wed, 25 Aug 2004 22:47:04 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1C04j1-00038v-Pz;
	Wed, 25 Aug 2004 20:50:31 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1C04j1-00038v-Pz
	for pobox@data-plan.com; Wed, 25 Aug 2004 20:50:31 +0000
Received: from [208.210.124.73] (helo=gold.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1C04j0-00002I-FU
	for pobox@data-plan.com; Wed, 25 Aug 2004 20:50:30 +0000
Received: from gold.pobox.com (localhost [127.0.0.1])
	by gold.pobox.com (Postfix) with ESMTP id AD1815463;
	Wed, 25 Aug 2004 16:50:29 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from gold (localhost [127.0.0.1])
	by gold.pobox.com (Postfix) with ESMTP id 85FFF55E7
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Wed, 25 Aug 2004 16:50:29 -0400 (EDT)
Received-SPF: none (gold.pobox.com: domain of timbo@dansat.data-plan.com does not designate permitted sender hosts)
Received: from mail04.svc.cra.dublin.eircom.net (mail04.svc.cra.dublin.eircom.net [159.134.118.20])
	by gold.pobox.com (Postfix) with SMTP id 14C005463
	for <Tim.Bunce@pobox.com>; Wed, 25 Aug 2004 16:50:25 -0400 (EDT)
Received: (qmail 5678 messnum 5046341 invoked from network[213.94.228.233/unknown]); 25 Aug 2004 20:50:23 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail04.svc.cra.dublin.eircom.net (qp 5678) with SMTP; 25 Aug 2004 20:50:23 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7PKsrof034865;
	Wed, 25 Aug 2004 21:54:53 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i7PKsqas034864;
	Wed, 25 Aug 2004 21:54:52 +0100 (BST)
Date: Wed, 25 Aug 2004 21:54:52 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Philipp Lang <pl@genericom.de>
Cc: Tim.Bunce@pobox.com
Subject: Re: DBD::Oracle: Freeing a temporary blob
Message-ID: <20040825205452.GC34655@dansat.data-plan.com>
References: <412CA445.FC2F9EF2@genericom.de>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <412CA445.FC2F9EF2@genericom.de>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 4674
Lines: 124

On Wed, Aug 25, 2004 at 04:37:57PM +0200, Philipp Lang wrote:
> Dear Tim,
> 
> first, I would really like to thank you for the great work you have done
> with your DBI/DBD work. We are using it extensively in several projects
> and we are highly pleased.

Thanks Philipp!

> Unfortunately I have now encountered a problem we need to fix urgently,
> since our customer's production is seriously  affected.
> 
> We tried for many days to find a solution (google, newsgroups,
> trial-and-error...), without luck. So my last chance is to contact you
> directly, although I assume you have a lot work yourself.

I am very busy and what little spare time I have for DBD::Oracle
is going into trying to get 1.16 released (which is proving to be
hard as we're tripping over Oracle bugs when an Oracle 8 client
talks to an Oracle 9+ server.) It's a major release that will help
many people so I need to give that priority.

Separately I am exploring ways to fund DBI and DBD::Oracle development
so I can devote more time to it. There's is much that needs to be
done and much more that could be done beyond that.

The Perl Foundation (TPF) have setup a way for people and companies
to make donations for DBI development [as yet unannounced so please
keep to yourself]. A note on the contribution could indicate that the
donor would like it used for a particular purpose, such as DBD::Oracle.

Anyway, to cut a long story short, it would be much easier to devote
time to this if it could be funded in some way.

I think the TPF setup is working so it could be done that way.
Alternatively you could contract me to do the work for you.
That would be quicker and simpler for you as TPF's non-profit
status doesn't make a difference to European donors.

My standard daily rate for add-hoc consulting is 1600 Euro.
I'd expect to be able to sort this out inside a day, and prefer
fixed-price quotes anyway, so would 1600 Euro be okay?

Of course, if you feel your company would like to either
make a general contribution to DBI/DBD::Oracle development beyond
that, or to fund the development of specific functionality that
would be of extra value to you then I'd be happy to talk about that.

I hate asking for money, and would much rather dig into the code and
reply with a patch, but it's just not practical for me now. Sorry.

Tim.

> ---
> 
> The problem:
> 
> Our database contains a stored function "ReadUnitBlob()" that returns a
> temporary blob: 
> 
> function ReadUnitBlob(UnitID_IN in integer) return blob
> is
> ...
> begin
>   ...
>   dbms_lob.createtemporary(retBlob, false, dbms_lob.call);
>   dbms_lob.loadfromfile(retBlob, bfileIn, fileLen);
>   ...
>   return retBlob;
> end;
> 
> We call this function in Perl in a big loop to fetch a lot of blobs (~
> 100000) using something like:
>  
> my $sth = $DBH->prepare("select ReadUnitBlob(:unitID) from dual", {
> ora_auto_lob => 0 });
> $sth->bind_param(":unitID", $unitID);
> $sth->execute();
> my ($loc) = $sth->fetchrow_array();
> $sth->finish();
> ...
> while(my $data = $DBH->ora_lob_read($loc, $offset, $chunk_size))
>   ...
> 
> Although this works, it has a big disadvantage: Oracle does not
> automaticaly free the temporary blob, so it shortly runs out of temp.
> space. (confirmed with "select * from v$temporary_lobs").
> 
> Acording to the Oracle docs this can be we solved by implicitly freeing
> the temp. blob, e.g. by calling the PLSQL method
> "dbms_lob.freetemporary()". I tried differnt ways to do this with
> DBD::Oracle, but never succeeded. I just did not manage to fetch the LOB
> locator from the my stored procedure and to pass it to a call of
> "dbms_lob.freetemporary()":
> 
> my $sth = $dbh->prepare("begin :bloc := ReadUnitBlob(:unitID); end;", {
> ora_auto_lob => 0 });
> my $bloc;
> $sth->bind_param_inout( ":bloc", \$bloc, ORA_BLOB);
> $sth->bind_param(":unitID", $unitID);
> $sth->execute();
> 
> obviously the "ORA_BLOB" type for bind_param_inout() is wrong here ;)
> 
> Can you help me??? Do you know a way how to free the temp. blob using
> DBD::Oracle (using Oracle::OCI is not possible, since the customer is
> strinctly refusing to install it).
> 
> Otherwise, would it be possible include an additional DBD::Oracle LOB
> Locator Method "ora_lob_freetemporary()" that warps
> "OCILobFreeTemporary" ?
> 
> Any help is really appreciated!
> 
> Greeting from Germany,
> 
>   Philipp
> 
> --
> Dipl. Inf. Philipp Lang                         Genericom Software GmbH
> Tel. +49 (0)7031/8739-26                              Tilsiter Str. 4-6
> Fax  +49 (0)7031/8739-11                             71065 Sindelfingen
> pl@genericom.de                                        www.genericom.de


From SRS0=eIh3=LQ=genericom.de=pl@bounce2.pobox.com  Thu Aug 26 14:06:45 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7QD6Som051890
	for <timbo@localhost>; Thu, 26 Aug 2004 14:06:45 +0100 (BST)
	(envelope-from SRS0=eIh3=LQ=genericom.de=pl@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 26 Aug 2004 14:06:45 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1C0HX2-0003PB-Sd;
	Thu, 26 Aug 2004 10:31:00 +0000
Received: from [194.217.242.223] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1C0HX2-0003PB-Sd
	for pobox@data-plan.com; Thu, 26 Aug 2004 10:31:00 +0000
Received: from [208.58.1.198] (helo=lime.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1C0HX2-0003BR-F8
	for pobox@data-plan.com; Thu, 26 Aug 2004 10:31:00 +0000
Received: from lime.pobox.com (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id DC4BFB0D27;
	Thu, 26 Aug 2004 06:30:59 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from lime (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id CE95AB0D7D
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Thu, 26 Aug 2004 06:30:59 -0400 (EDT)
Received-SPF: none (lime.pobox.com: domain of pl@genericom.de does not designate permitted sender hosts)
X-Pobox-Antispam: dnsbl/blackholes.five-ten-sg.com returned DENY: for 81.169.145.165(natsmtp00.rzone.de)
Received: from natsmtp00.rzone.de (natsmtp00.rzone.de [81.169.145.165])
	by lime.pobox.com (Postfix) with ESMTP id 71107B0D27
	for <Tim.Bunce@pobox.com>; Thu, 26 Aug 2004 06:30:56 -0400 (EDT)
Received: from genericom.de (pD9E61E09.dip.t-dialin.net [217.230.30.9])
	by post.webmailer.de (8.12.10/8.12.10) with ESMTP id i7QAUoTY009695
	for <Tim.Bunce@pobox.com>; Thu, 26 Aug 2004 12:30:51 +0200 (MEST)
Sender: pl@post.webmailer.de
Message-ID: <412DBBD7.2C124831@genericom.de>
Date: Thu, 26 Aug 2004 12:30:47 +0200
From: Philipp Lang <pl@genericom.de>
Organization: Genericom Software
X-Mailer: Mozilla 4.77 [en] (X11; U; Linux 2.4.24 i686)
X-Accept-Language: de, en
MIME-Version: 1.0
To: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: DBD::Oracle: Freeing a temporary blob
References: <412CA445.FC2F9EF2@genericom.de> <20040825205452.GC34655@dansat.data-plan.com>
Content-Type: multipart/signed; protocol="application/x-pkcs7-signature"; micalg=sha1; boundary="------------msB92907D67E7D4C0121D50420"
Status: O
X-Status: A
Content-Length: 3040
Lines: 58

This is a cryptographically signed message in MIME format.

--------------msB92907D67E7D4C0121D50420
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

Tim Bunce wrote:
> 
> I hate asking for money, and would much rather dig into the code and
> reply with a patch, but it's just not practical for me now. Sorry.

Thanks for your quick reply. I can fully understand your position in
this issue. We will need to submit this issue to our customer, and
eventually it will be their decision, since a) the problem technically
originates in external components
and b) our work is payed on a time and material basis.

Thanks again,
  Philipp

--
Dipl. Inf. Philipp Lang                         Genericom Software GmbH
Tel. +49 (0)7031/8739-26                              Tilsiter Str. 4-6
Fax  +49 (0)7031/8739-11                             71065 Sindelfingen
pl@genericom.de                                        www.genericom.de
--------------msB92907D67E7D4C0121D50420
Content-Type: application/x-pkcs7-signature; name="smime.p7s"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="smime.p7s"
Content-Description: S/MIME Cryptographic Signature

MIIFLgYJKoZIhvcNAQcCoIIFHzCCBRsCAQExCzAJBgUrDgMCGgUAMAsGCSqGSIb3DQEHAaCC
Aw0wggMJMIICcqADAgECAg4WKgAAAALXCfeUwksXHjANBgkqhkiG9w0BAQQFADCBvDELMAkG
A1UEBhMCREUxEDAOBgNVBAgTB0hhbWJ1cmcxEDAOBgNVBAcTB0hhbWJ1cmcxOjA4BgNVBAoT
MVRDIFRydXN0Q2VudGVyIGZvciBTZWN1cml0eSBpbiBEYXRhIE5ldHdvcmtzIEdtYkgxIjAg
BgNVBAsTGVRDIFRydXN0Q2VudGVyIENsYXNzIDEgQ0ExKTAnBgkqhkiG9w0BCQEWGmNlcnRp
ZmljYXRlQHRydXN0Y2VudGVyLmRlMB4XDTAzMTIwODA5NTQyNFoXDTA1MDEzMDA5NTQyNFow
RDELMAkGA1UEBhMCREUxFTATBgNVBAMTDFBoaWxpcHAgTGFuZzEeMBwGCSqGSIb3DQEJARYP
cGxAZ2VuZXJpY29tLmRlMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAJqCn5ZXevTm3KgAKlKk
tOMzn1utWbcKoyrjuUSUOk9hwKXqjCtlBrNUDfVCtJIFWTU/2diijqormxUCXYr60F8CAwEA
AaOByDCBxTAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIF4DAzBglghkgBhvhCAQgEJhYk
aHR0cDovL3d3dy50cnVzdGNlbnRlci5kZS9ndWlkZWxpbmVzMBEGCWCGSAGG+EIBAQQEAwIF
oDBdBglghkgBhvhCAQMEUBZOaHR0cHM6Ly93d3cudHJ1c3RjZW50ZXIuZGUvY2dpLWJpbi9j
aGVjay1yZXYuY2dpLzE2MkEwMDAwMDAwMkQ3MDlGNzk0QzI0QjE3MUU/MA0GCSqGSIb3DQEB
BAUAA4GBAI4bC7MGQQTY9Cp09FYwPychOQs8yFNKHrqYwFhXOirqVTqwo1wgxuSO5/fYWbcs
neWGio3swv0y+jn7o0gkrr/pHNbbm/YmCMuiGuwciH2y4GU2BOukFFP4Otke5UL9Yc9l13eG
Aoaf9ApqRrckhbhLhjz3+gyUM5XRYpoOZX0LMYIB6TCCAeUCAQEwgc8wgbwxCzAJBgNVBAYT
AkRFMRAwDgYDVQQIEwdIYW1idXJnMRAwDgYDVQQHEwdIYW1idXJnMTowOAYDVQQKEzFUQyBU
cnVzdENlbnRlciBmb3IgU2VjdXJpdHkgaW4gRGF0YSBOZXR3b3JrcyBHbWJIMSIwIAYDVQQL
ExlUQyBUcnVzdENlbnRlciBDbGFzcyAxIENBMSkwJwYJKoZIhvcNAQkBFhpjZXJ0aWZpY2F0
ZUB0cnVzdGNlbnRlci5kZQIOFioAAAAC1wn3lMJLFx4wCQYFKw4DAhoFAKCBsTAYBgkqhkiG
9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0wNDA4MjYxMDMwNDhaMCMGCSqG
SIb3DQEJBDEWBBQbWUdl+peoD/lHpzCOnuQfzAsbJzBSBgkqhkiG9w0BCQ8xRTBDMAoGCCqG
SIb3DQMHMA4GCCqGSIb3DQMCAgIAgDAHBgUrDgMCBzANBggqhkiG9w0DAgIBQDANBggqhkiG
9w0DAgIBKDANBgkqhkiG9w0BAQEFAARAXzFame8ymLqgf+7nZ4V7L9e9J+aG6z5ipa+iv76v
EFAg5QObdHdvTnq5QEAjEnLKgeUGvdgpS6PA0h+beEIeIA==
--------------msB92907D67E7D4C0121D50420--


From SRS0=T6ya=LQ=dansat.data-plan.com=timbo@bounce2.pobox.com  Thu Aug 26 16:42:55 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7QFgKp1054926
	for <timbo@localhost>; Thu, 26 Aug 2004 16:42:55 +0100 (BST)
	(envelope-from SRS0=T6ya=LQ=dansat.data-plan.com=timbo@bounce2.pobox.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Thu, 26 Aug 2004 16:42:55 +0100 (BST)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@data-plan.com id 1C0L1E-0005sL-5Z;
	Thu, 26 Aug 2004 14:14:24 +0000
Received: from [194.217.242.211] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1C0L1E-0005sL-5Z
	for pobox@data-plan.com; Thu, 26 Aug 2004 14:14:24 +0000
Received: from [208.58.1.198] (helo=lime.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1C0L1E-0001t1-Cm
	for pobox@data-plan.com; Thu, 26 Aug 2004 14:14:24 +0000
Received: from lime.pobox.com (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id 541E8AFAD6;
	Thu, 26 Aug 2004 10:14:23 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from lime (localhost [127.0.0.1])
	by lime.pobox.com (Postfix) with ESMTP id 1C39FB0747
	for <tim.bunce@pobox.com.13888548.001.icgmh>; Thu, 26 Aug 2004 10:14:23 -0400 (EDT)
Received-SPF: none (lime.pobox.com: domain of timbo@dansat.data-plan.com does not designate permitted sender hosts)
Received: from mail01.svc.cra.dublin.eircom.net (mail01.svc.cra.dublin.eircom.net [159.134.118.17])
	by lime.pobox.com (Postfix) with SMTP id BFBB5AFAD6
	for <Tim.Bunce@pobox.com>; Thu, 26 Aug 2004 10:14:19 -0400 (EDT)
Received: (qmail 12246 messnum 7731352 invoked from network[213.94.228.233/unknown]); 26 Aug 2004 14:14:17 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail01.svc.cra.dublin.eircom.net (qp 12246) with SMTP; 26 Aug 2004 14:14:17 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i7QEItof052863;
	Thu, 26 Aug 2004 15:18:55 +0100 (BST)
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i7QEItr3052862;
	Thu, 26 Aug 2004 15:18:55 +0100 (BST)
Date: Thu, 26 Aug 2004 15:18:55 +0100
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Philipp Lang <pl@genericom.de>
Cc: Tim Bunce <Tim.Bunce@pobox.com>
Subject: Re: DBD::Oracle: Freeing a temporary blob
Message-ID: <20040826141855.GC52359@dansat.data-plan.com>
References: <412CA445.FC2F9EF2@genericom.de> <20040825205452.GC34655@dansat.data-plan.com> <412DBBD7.2C124831@genericom.de>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <412DBBD7.2C124831@genericom.de>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 926
Lines: 25

Okay. Thanks. Let me know how it turns out.

Tim.

On Thu, Aug 26, 2004 at 12:30:47PM +0200, Philipp Lang wrote:
> Tim Bunce wrote:
> > 
> > I hate asking for money, and would much rather dig into the code and
> > reply with a patch, but it's just not practical for me now. Sorry.
> 
> Thanks for your quick reply. I can fully understand your position in
> this issue. We will need to submit this issue to our customer, and
> eventually it will be their decision, since a) the problem technically
> originates in external components
> and b) our work is payed on a time and material basis.
> 
> Thanks again,
>   Philipp
> 
> --
> Dipl. Inf. Philipp Lang                         Genericom Software GmbH
> Tel. +49 (0)7031/8739-26                              Tilsiter Str. 4-6
> Fax  +49 (0)7031/8739-11                             71065 Sindelfingen
> pl@genericom.de                                        www.genericom.de


