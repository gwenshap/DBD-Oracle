From dbi-users-return-11724-Tim.Bunce=pobox.com@perl.org  Fri May 31 15:39:50 2002
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.11.6/8.11.6) with ESMTP id g4VEdno73229
	for <timbo@localhost>; Fri, 31 May 2002 15:39:49 +0100 (BST)
	(envelope-from dbi-users-return-11724-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.22]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 31 May 2002 15:39:49 +0100 (BST)
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@data-plan.com
          id 1022854157:20:06570:1; Fri, 31 May 2002 14:09:17 GMT
Received: from dolly1.pobox.com ([207.106.49.22]) by punt-2.mail.demon.net
           id aa2005972; 31 May 2002 14:08 GMT
Received: from dolly1.pobox.com (localhost.localdomain [127.0.0.1])
	by dolly1.pobox.com (Postfix) with ESMTP id 210F42BF43
	for <Tim.Bunce@data-plan.com>; Fri, 31 May 2002 10:08:39 -0400 (EDT)
Delivered-To: tim.bunce@pobox.com
Received: from onion.perl.org (unknown [64.70.54.95])
	by dolly1.pobox.com (Postfix) with SMTP id 8D88B2BF11
	for <Tim.Bunce@pobox.com>; Fri, 31 May 2002 10:08:38 -0400 (EDT)
Received: (qmail 47355 invoked by uid 1005); 31 May 2002 14:07:42 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 47340 invoked by uid 76); 31 May 2002 14:07:41 -0000
Received: from wsrgeh.wsr.ac.at (HELO wsrgeh.wsr.ac.at) (143.130.16.2)
  by onion.perl.org (qpsmtpd/0.07b) with SMTP; Fri May 31 14:07:41 2002 -0000
Received: from dialog.wsr.ac.at (dialog.wsr.ac.at [143.130.50.66])
	by wsrgeh.wsr.ac.at (8.11.6/8.11.6) with ESMTP id g4VE8Or11772
	for <dbi-users@perl.org>; Fri, 31 May 2002 16:08:24 +0200
Received: (from hjp@localhost)
	by dialog.wsr.ac.at (8.11.6/8.11.6) id g4VE8Nf12538
	for dbi-users@perl.org; Fri, 31 May 2002 16:08:23 +0200
Date: Fri, 31 May 2002 16:08:23 +0200
From: "Peter J. Holzer" <hjp@wsr.ac.at>
To: dbi-users@perl.org
Subject: Re: Insert a blank value into Oracle
Message-ID: <20020531160823.F28779@wsr.ac.at>
Mail-Followup-To: "Peter J. Holzer" <hjp@wsr.ac.at>,
	dbi-users@perl.org
References: <1797C3D07B8BD311BC9200A0C9C85E0F0369DCCF@mail.gss.com.tw>
Mime-Version: 1.0
Content-Type: multipart/signed; micalg=pgp-md5;
	protocol="application/pgp-signature"; boundary="aZoGpuMECXJckB41"
Content-Disposition: inline
User-Agent: Mutt/1.2.5.1i
In-Reply-To: <1797C3D07B8BD311BC9200A0C9C85E0F0369DCCF@mail.gss.com.tw>; from larry_wu@mail.gss.com.tw on Fri, May 31, 2002 at 06:38:45PM +0800
Status: RO
Content-Length: 2819
Lines: 74

--aZoGpuMECXJckB41
Content-Type: text/plain; charset=iso-8859-1
Content-Disposition: inline
Content-Transfer-Encoding: quoted-printable

On 2002-05-31 18:38:45 +0800, Larry Wu (=A7d=A4l=B7=D3) wrote:
> I encountered a problem to insert a space value ( like ' ' ) into Oracle
> database.
[...]
> Unfortunately, I have a table A contained a not allow null column
> NotNullCol. Now I want to insert a row like below:
>=20
> 	$sth =3D $dbh->prepare( qq{ insert into A ( KeyCol, NotNullCol )
> values (?,?)} );
> 	$sth->bind_param(1, '1');
> 	$sth->bind_param(2, ' ');
> 	$sth->execute;
>=20
> When I executed this file I got an error from Oracle: Can't insert NULL
> value into ( "A"."NotNullCol") (DBD ERROR: OCIStmtExecute).
> I think the space value was truncated in the process. Could any one tell =
me
> how to keep a blank space in my bind_param ?

use DBD::Oracle qw(:ora_types);
[...]
$sth->bind_param(2, ' ', { ora_type =3D> ORA_CHAR });

This is a frequently asked question here. The default type for strings,
ORA_VARCHAR2, strips trailing blanks from strings. A few months ago,
during one of the diskussuions about this feature, Tim said that he
might add a way to change the default in a future version of
DBD::Oracle. If he doesn't, maybe a paragraph like the following should
be added to the doc (not sure where - it fits below "Using DBD::Oracle
with Oracle 8 - Features and Issues" but it isn't Oracle 8 specific):

    =3Dhead2 Inserting strings with trailing spaces

    OCI provides several string types which behave differently.
    Unfortunately, none of them can store arbitrary perl strings.
    By default, DBD::Oracle binds string variables as ORA_VARCHAR2,
    which allows embedded NUL characters but strips trailing spaces. If
    you need trailing spaces, but don't need embedded NUL characters,
    you can explicetly bind the param to type ORA_CHAR with:

	$sth->bind_param(($field_num, $string_value,
	                 { ora_type =3D> ORA_CHAR });

   =20
	hp

--=20
   _  | Peter J. Holzer      | Aeltere Sources (also solche, die schon
|_|_) | Sysadmin WSR / LUGA  | aelter als 12 Stunden sind) sollte man
| |   | hjp@wsr.ac.at        | bei Linux generell nicht einsetzen -
__/   | http://www.hjp.at/   | Real Time Linux??    -- Gerhard Schneider

--aZoGpuMECXJckB41
Content-Type: application/pgp-signature
Content-Disposition: inline

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.0.6 (GNU/Linux)
Comment: For info see http://www.gnupg.org

iQDQAwUBPPeD11LjemazOuKpAQEtNAXUC6rFL0C0v6MNW/K5ggXcSDY7Xvrj6Ed/
jqjHq2Dx+h2rIMWXCDIGZVphSG74u4FL41AQF/rzGR/e56qH7aAxVmaiLdQE/DRi
zzsoOHoPEg96FhHljDtCZyxHzsz9sRJ1dfW1PELn5r2OSYPPsVzMoeR4iEXnVjvV
ZYH/OfbKRKhysIHjcNYKcyQL87GXdjzCEas3Xz+jyxW2vqzGAwUfTim4ySY9rF37
c5vopwrTFCsi58r1LccFhQqEfw==
=Xe8d
-----END PGP SIGNATURE-----

--aZoGpuMECXJckB41--

