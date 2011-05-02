From dbi-dev-return-2935-Tim.Bunce=pobox.com@perl.org  Fri Jan 30 12:50:15 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0UClt3q069307
	for <timbo@localhost>; Fri, 30 Jan 2004 12:50:14 GMT
	(envelope-from dbi-dev-return-2935-Tim.Bunce=pobox.com@perl.org)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 30 Jan 2004 12:50:14 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AmWGJ-00057X-AG;
	Fri, 30 Jan 2004 10:52:35 +0000
Received: from [194.217.242.210] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1AmWGJ-00057X-AG
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 10:52:35 +0000
Received: from [207.8.214.3] (helo=puzzle.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1AmWGI-0007XK-P3
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 10:52:34 +0000
Received: from puzzle.pobox.com (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 029E8701C6
	for <pobox@dbi.demon.co.uk>; Fri, 30 Jan 2004 05:52:34 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by puzzle.pobox.com (Postfix) with ESMTP id 12ABF701C1
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 05:52:30 -0500 (EST)
Received: from onion.perl.org (onion.develooper.com [63.251.223.166])
	by puzzle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 05:51:10 -0500 (EST)
Received: (qmail 33345 invoked by uid 1005); 30 Jan 2004 10:50:36 -0000
Mailing-List: contact dbi-dev-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-dev@perl.org>
List-Help: <mailto:dbi-dev-help@perl.org>
List-Unsubscribe: <mailto:dbi-dev-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-dev-subscribe@perl.org>
Delivered-To: mailing list dbi-dev@perl.org
Received: (qmail 33175 invoked by uid 76); 30 Jan 2004 10:50:26 -0000
Received: from qmailr@one.develooper.com (HELO ran-out.mx.develooper.com) (64.81.84.115) by onion.perl.org (qpsmtpd/0.26) with SMTP; Fri, 30 Jan 2004 02:50:25 -0800
Received: (qmail 21117 invoked by uid 225); 30 Jan 2004 10:48:52 -0000
Delivered-To: dbi-dev@perl.org
Received: (qmail 21080 invoked by uid 507); 30 Jan 2004 10:48:49 -0000
Received: from [212.89.121.1] (HELO babel.morphochem.de) (212.89.121.1)  by one.develooper.com (qpsmtpd/0.27-dev) with ESMTP; Fri, 30 Jan 2004 02:48:46 -0800
Received: (qmail 31958 invoked from network); 30 Jan 2004 11:50:38 -0000
Received: from unknown (HELO mail.morphochem.de) (10.1.15.5)  by 212.89.121.1 with SMTP; 30 Jan 2004 11:50:38 -0000
Received: (qmail 6921 invoked from network); 30 Jan 2004 10:49:58 -0000
Received: from localhost.morphochem.de (HELO mail) ([127.0.0.1])          (envelope-sender <hendrik.fuss@morphochem.de>)          by localhost.morphochem.de (qmail-ldap-1.03) with SMTP          for <dbi-dev@perl.org>; 30 Jan 2004 10:49:58 -0000
Received: from mars.MORPHOCHEM.de ([10.1.8.130])	by mail.morphochem.de (MailMonitor for SMTP v1.2.1 ) ;	Fri, 30 Jan 2004 11:49:58 +0100 (CET)
Subject: DBD-Oracle and XMLType
From: Hendrik Fuss <hendrik.fuss@morphochem.de>
To: "dbi-dev@perl.org" <dbi-dev@perl.org>
Content-Type: multipart/mixed; boundary="=-fkyM33WAvQ5xV0uCPeSD"
X-Mailer: Ximian Evolution 1.0.8 
Date: 30 Jan 2004 11:41:31 +0100
Message-Id: <1075459292.7305.46.camel@mars>
Mime-Version: 1.0
X-Spam-Check-By: one.develooper.com
X-Spam-Status: No, hits=0.5 required=7.0 tests=MIME_LONG_LINE_QP,QUOTED_EMAIL_TEXT,SPAM_PHRASE_00_01,TO_ADDRESS_EQ_REAL version=2.44
X-SMTPD: qpsmtpd/0.26, http://develooper.com/code/qpsmtpd/
Status: RO
X-Status: A
Content-Length: 8148
Lines: 302

--=-fkyM33WAvQ5xV0uCPeSD
Content-Type: text/plain; charset=ISO-8859-1
Content-Transfer-Encoding: quoted-printable

Hi everyone,

It's been a while since I last posted here. In September 2003 I was
trying to add support for binding XMLType objects to DBD-Oracle, so that
you could easily insert large (ie >4k) XML data into an XMLType table.

Unfortunately my employer fired me in October 2003 and in the remaining
time I had to work on other projects, so I wasn't able to complete the
DBD project. Since I won't have access to an oracle database from now
on, I thought the least I can do is to provide my code as it is to the
list. Blame German economy. :-(

The attached patch (based on DBD-Oracle 1.15) enables you to upload
XMLType objects (OCIXMLTypePtr) by binding them as SQLT_NTY. In dbdimp.c
I added a function dbd_rebind_ph_nty for that purpose. You need to
create that XMLType object first using the C function
createxmlfromstring in xml.c.

The XMLType object is either created from an OCIString or from a
temporary CLOB depending on the length of the source string. Have a look
at the bottom of ociap.h, all the (undocumented) XMLType functions are
there, and there are also some constants in oci.h.

I'm not sure if the CLOB code currently works.

Here is another code fragment:

  my $xml =3D createxml($dbh, '<test>Test document</test>');
  my $sth =3D $dbh->prepare('INSERT INTO xml_type VALUES (?)');
  $sth->bind_param(1, $xml, { ora_type =3D> 108 }); # SQLT_NTY
  $sth->execute();

Please note that this code is really just early development, which I
wouldn't publish under normal circumstances. :) I just hope it might me
useful to someone.

Well then, time to say goodbye
thanks to Tim and everyone who contributed to dbi for a great piece of
software

Cheers,
Hendrik

--=20
hendrik fu=DF

morphochem AG
gmunder str. 37-37a
81379 muenchen

tel. ++49-89-78005-0
fax  ++49-89-78005-555

hendrik.fuss@morphochem.de
http://www.morphochem.de

--=-fkyM33WAvQ5xV0uCPeSD
Content-Description: 
Content-Disposition: attachment; filename=dbdimp.c.diff
Content-Transfer-Encoding: quoted-printable
Content-Type: text/plain; charset=ISO-8859-1

151a152
>     case 108:   /* SQLT_NTY     */
992a994,996
>     case SQL_UDT:
> 	return 108;     /* Oracle NTY           */
>=20
1004a1009,1072
> static int
> dbd_rebind_ph_nty(sth, imp_sth, phs)
>     SV* sth;
>     imp_sth_t *imp_sth;
>     phs_t *phs;
> {
>     OCIType *tdo =3D NULL;
>     sword status;
>     SV* ptr;
>=20
>     if (phs->is_inout)
> 	croak("OUT binding for NTY is currently unsupported");
>=20
>     /* ensure that the value is a support named object type */
>     /* (currently only OCIXMLType*)                         */
>     if ( sv_isa(phs->sv, "OCIXMLTypePtr") ) {
> 	OCITypeByName(imp_sth->envhp, imp_sth->errhp, imp_sth->svchp,
> 		      (CONST text*)"SYS", 3,
> 		      (CONST text*)"XMLTYPE", 7,
> 		      (CONST text*)0, 0,
> 		      OCI_DURATION_CALLOUT, OCI_TYPEGET_HEADER,
> 		      &tdo);
>=20
> 	ptr =3D SvRV(phs->sv);
> 	phs->progv  =3D (void*) SvIV(ptr);
> 	phs->maxlen =3D sizeof(OCIXMLType*);
>     }
>     else
> 	croak("Unsupported named object type for bind parameter");
>=20
>=20
>     /* bind by name */
>=20
>     OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
> 			   (text*)phs->name, (sb4)strlen(phs->name),
> 			   (dvoid *) NULL, /* value supplied in BindObject later */
> 			   0,
> 			   (ub2)phs->ftype, 0,
> 			   NULL,
> 			   0, 0,
> 			   NULL,
> 			   (ub4)OCI_DEFAULT,
> 			   status
> 			   );
>=20
>     if (status !=3D OCI_SUCCESS) {
>       oci_error(sth, imp_sth->errhp, status, "OCIBindByName SQLT_NTY");
>       return 0;
>     }
>     if (DBIS->debug >=3D 3)
> 	PerlIO_printf(DBILOGFP, "    pp_rebind_ph_nty: END\n");
>=20
>=20
>     /* bind the object */
>=20
>     OCIBindObject(phs->bndhp, imp_sth->errhp,
> 		  (CONST OCIType*)tdo,
> 		  (dvoid **)&phs->progv,
> 		  (ub4*)NULL,
> 		  (dvoid **)NULL,
> 		  (ub4*)NULL);
>=20
>     return 2;
> }
1309a1378,1380
>     case 108:
> 	    done =3D dbd_rebind_ph_nty(sth, imp_sth, phs);
> 	    break;
1331c1403
< 	int at_exec =3D (phs->desc_h =3D=3D NULL);
---
> 	int at_exec =3D (phs->desc_h =3D=3D NULL) && (phs->ftype !=3D 108);
1419c1491
<     if (SvROK(newvalue) && !IS_DBI_HANDLE(newvalue))
---
>     if (SvROK(newvalue) && (!IS_DBI_HANDLE(newvalue)) && (sql_type!=3DSQL=
T_NTY))
1420a1493
> 	/* ref allowed for OCIXMLType* */
2219a2293
>     case SQLT_NTY:  sql_fbh.dbtype =3D SQL_UDT;           break;

--=-fkyM33WAvQ5xV0uCPeSD
Content-Disposition: attachment; filename=xml.c
Content-Transfer-Encoding: quoted-printable
Content-Type: text/plain; name=xml.c; charset=ISO-8859-1

#include "oci.h"
#include <stdio.h>

/*  This helper function creates an XMLType object from a string source.
 *
 *  The resulting object can be bound to a placeholder, if ora_type =3D>
 *  SQLT_NTY is specified.
 */

static void checkerr(errhp, status)
OCIError *errhp;
sword status;
{
    text errbuf[512];
    ub4 buflen;
    sb4 errcode;

    switch (status)
    {
        case OCI_SUCCESS:
            break;
        case OCI_SUCCESS_WITH_INFO:
            printf("Error - OCI_SUCCESS_WITH_INFO\n");
            break;
        case OCI_NEED_DATA:
            printf("Error - OCI_NEED_DATA\n");
            break;
        case OCI_NO_DATA:
            printf("Error - OCI_NO_DATA\n");
            break;
        case OCI_ERROR:
            OCIErrorGet ((dvoid *) errhp, (ub4) 1, (text *) NULL, &errcode,
            errbuf, (ub4) sizeof(errbuf), (ub4) OCI_HTYPE_ERROR);
            printf("Error - %s\n", errbuf);
            exit(1);
            break;
        case OCI_INVALID_HANDLE:
            printf("Error - OCI_INVALID_HANDLE\n");
            break;
        case OCI_STILL_EXECUTING:
            printf("Error - OCI_STILL_EXECUTE\n");
            break;
        case OCI_CONTINUE:
            printf("Error - OCI_CONTINUE\n");
            break;
        default:
        break;
    }
}


#define MAX_OCISTRING_LEN 32766

SV* createxmlfromstring(SV* dbh, char* source) {
  OCIXMLType *xml =3D NULL;
  ub4 len;
  ub1 src_type;
  dvoid* src_ptr =3D NULL;
  D_imp_dbh(dbh);
  SV* sv_dest;

  len =3D strlen(source);
  if(len > MAX_OCISTRING_LEN) {
      src_type =3D OCI_XMLTYPE_CREATE_CLOB;

      printf("OCIDescriptorAlloc\n");
      checkerr( imp_dbh->errhp,
		OCIDescriptorAlloc((dvoid*)imp_dbh->envhp,
				   (dvoid **)&src_ptr,
				   (ub4)OCI_DTYPE_LOB,
				   (size_t)0,
				   (dvoid**)0) );

      printf("OCILobCreateTemporary\n");
      checkerr( imp_dbh->errhp,
		OCILobCreateTemporary(imp_dbh->svchp,
				      imp_dbh->errhp,=20
				      (OCILobLocator*) src_ptr,
				      (ub2)0,=20
				      SQLCS_IMPLICIT,=20
				      OCI_TEMP_CLOB,=20
				      OCI_ATTR_NOCACHE,=20
				      OCI_DURATION_SESSION) );

      printf("OCILobWrite\n");
      checkerr (imp_dbh->errhp,
		OCILobWriteAppend(imp_dbh->svchp,
				  imp_dbh->errhp,
				  (OCILobLocator*) src_ptr,
				  &len,=20
				  (ub1*)source,
				  len,
				  OCI_ONE_PIECE,
				  (dvoid *)0,=20
				  (sb4 (*)(dvoid*,dvoid*,ub4*,ub1 *))0,
				  0,
				  SQLCS_IMPLICIT));

  } else {
      src_type =3D OCI_XMLTYPE_CREATE_OCISTRING;

      printf("OCIStringAssignText\n");
      checkerr( imp_dbh->errhp,
		OCIStringAssignText(imp_dbh->envhp,
				    imp_dbh->errhp,=20
				    (CONST text*) source,=20
				    (ub2) strlen(source),
				    (OCIString **) &src_ptr)
	  );
  }

  printf("OCIXMLTypeCreateFromSrc\n");
  checkerr( imp_dbh->errhp,
	    OCIXMLTypeCreateFromSrc(imp_dbh->svchp,
				    imp_dbh->errhp,
				    (OCIDuration)OCI_DURATION_CALLOUT,
				    (ub1)src_type,
				    (dvoid *)src_ptr,
				    (sb4)OCI_IND_NOTNULL,
				    &xml)
      );


  /* free temporary resources */
  if( src_type =3D=3D OCI_XMLTYPE_CREATE_CLOB ) {
      checkerr( imp_dbh->errhp,
		OCILobFreeTemporary(imp_dbh->svchp, imp_dbh->errhp,
				    (OCILobLocator*) src_ptr) );

      checkerr( imp_dbh->errhp,
		OCIDescriptorFree((dvoid *) src_ptr, (ub4) OCI_DTYPE_LOB) );
  }


  sv_dest =3D newSViv(0);
  sv_setref_pv(sv_dest, "OCIXMLTypePtr", xml);
  return sv_dest;
}

--=-fkyM33WAvQ5xV0uCPeSD--



From hendrik.fuss@morphochem.de  Fri Jan 30 16:56:30 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0UGsO3v071338
	for <timbo@localhost>; Fri, 30 Jan 2004 16:56:27 GMT
	(envelope-from hendrik.fuss@morphochem.de)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 30 Jan 2004 16:56:27 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AmZJF-0001wN-DK;
	Fri, 30 Jan 2004 14:07:49 +0000
Received: from [194.217.242.211] (helo=lon1-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1AmZJF-0001wN-DK
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 14:07:49 +0000
Received: from [208.58.1.193] (helo=boggle.pobox.com)
	by lon1-hub.mail.demon.net with esmtp id 1AmZJE-0003GM-Bm
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 14:07:48 +0000
Received: from boggle.pobox.com (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id 334DE30C57
	for <pobox@dbi.demon.co.uk>; Fri, 30 Jan 2004 09:07:47 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by boggle.pobox.com (Postfix) with ESMTP id E65B230C2C
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 09:07:45 -0500 (EST)
Received: from babel.morphochem.de (unknown [212.89.121.1])
	by boggle.pobox.com (Postfix) with ESMTP
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 09:07:04 -0500 (EST)
Received: (qmail 29768 invoked from network); 30 Jan 2004 15:10:09 -0000
Received: from unknown (HELO mail.morphochem.de) (10.1.15.5)
  by 212.89.121.1 with SMTP; 30 Jan 2004 15:10:09 -0000
Received: (qmail 11736 invoked from network); 30 Jan 2004 14:09:30 -0000
Received: from localhost.morphochem.de (HELO mail) ([127.0.0.1])
          (envelope-sender <hendrik.fuss@morphochem.de>)
          by localhost.morphochem.de (qmail-ldap-1.03) with SMTP
          for <Tim.Bunce@pobox.com>; 30 Jan 2004 14:09:30 -0000
Received: from mars.MORPHOCHEM.de ([10.1.8.130])
	by mail.morphochem.de (MailMonitor for SMTP v1.2.1 ) ;
	Fri, 30 Jan 2004 15:09:30 +0100 (CET)
Subject: Re: DBD-Oracle and XMLType
From: Hendrik Fuss <hendrik.fuss@morphochem.de>
To: Tim Bunce <Tim.Bunce@pobox.com>
Cc: "dbi-dev@perl.org" <dbi-dev@perl.org>
In-Reply-To: <20040130133443.GC70215@dansat.data-plan.com>
References: <1075459292.7305.46.camel@mars> 
	<20040130133443.GC70215@dansat.data-plan.com>
Content-Type: multipart/mixed; boundary="=-Sq1IOPDEhKoqxUKefiS3"
X-Mailer: Ximian Evolution 1.0.8 
Date: 30 Jan 2004 15:01:03 +0100
Message-Id: <1075471263.7305.73.camel@mars>
Mime-Version: 1.0
Status: RO
X-Status: A
Content-Length: 5585
Lines: 196


--=-Sq1IOPDEhKoqxUKefiS3
Content-Type: text/plain; charset=ISO-8859-1
Content-Transfer-Encoding: quoted-printable

> > The attached patch (based on DBD-Oracle 1.15) enables you to upload
> > XMLType objects (OCIXMLTypePtr) by binding them as SQLT_NTY. In dbdimp.=
c
> > I added a function dbd_rebind_ph_nty for that purpose. You need to
> > create that XMLType object first using the C function
> > createxmlfromstring in xml.c.
>=20
> I there any chance you could post that as a context diff (diff -u ideally
> or else diff -c)? It's much safer and more useful. Thanks.

Good idea. Here's a diff -u of dbdimp.c.

By the way: I have thougt about general support of named types, not just
XMLType, but you need to get the type description (TDO) from somewhere.
My code just checks if the perl variable is a blessed reference of
"OCIXMLTypePtr".

Also note that my code can't handle downloading of XMLType objects yet.

best wishes,
Hendrik

--=20
hendrik fu=DF

morphochem AG
gmunder str. 37-37a
81379 muenchen

tel. ++49-89-78005-0
fax  ++49-89-78005-555

hendrik.fuss@morphochem.de
http://www.morphochem.de

--=-Sq1IOPDEhKoqxUKefiS3
Content-Description: Context diff for dbdimp.c
Content-Disposition: attachment; filename=dbdimp.c.diff
Content-Transfer-Encoding: quoted-printable
Content-Type: text/plain; charset=ISO-8859-1

--- dbdimp.c.orig	2004-01-30 14:48:55.000000000 +0100
+++ dbdimp.c	2003-10-07 12:17:17.000000000 +0200
@@ -1,5 +1,5 @@
 /*
-   $Id: dbdimp.c,v 1.1.1.1 2003/10/02 10:45:20 hfuss Exp $
+   $Id: dbdimp.c,v 1.3 2003/10/07 10:17:17 hfuss Exp $
=20
    Copyright (c) 1994,1995,1996,1997,1998  Tim Bunce
=20
@@ -149,6 +149,7 @@
     case 97:	/* CHARZ	*/
     case 106:	/* MLSLABEL	*/
     case 102:	/* SQLT_CUR	OCI 7 cursor variable	*/
+    case 108:   /* SQLT_NTY     */
     case 112:	/* SQLT_CLOB / long	*/
     case 113:	/* SQLT_BLOB / long	*/
     case 116:	/* SQLT_RSET	OCI 8 cursor variable	*/
@@ -990,6 +991,9 @@
     case SQL_LONGVARCHAR:
 	return 8;	/* Oracle LONG		*/
=20
+    case SQL_UDT:
+	return 108;     /* Oracle NTY           */
+
     case SQL_DATE:
     case SQL_TIME:
     case SQL_TIMESTAMP:
@@ -1002,6 +1006,70 @@
 }
=20
=20
+static int
+dbd_rebind_ph_nty(sth, imp_sth, phs)
+    SV* sth;
+    imp_sth_t *imp_sth;
+    phs_t *phs;
+{
+    OCIType *tdo =3D NULL;
+    sword status;
+    SV* ptr;
+
+    if (phs->is_inout)
+	croak("OUT binding for NTY is currently unsupported");
+
+    /* ensure that the value is a support named object type */
+    /* (currently only OCIXMLType*)                         */
+    if ( sv_isa(phs->sv, "OCIXMLTypePtr") ) {
+	OCITypeByName(imp_sth->envhp, imp_sth->errhp, imp_sth->svchp,
+		      (CONST text*)"SYS", 3,
+		      (CONST text*)"XMLTYPE", 7,
+		      (CONST text*)0, 0,
+		      OCI_DURATION_CALLOUT, OCI_TYPEGET_HEADER,
+		      &tdo);
+
+	ptr =3D SvRV(phs->sv);
+	phs->progv  =3D (void*) SvIV(ptr);
+	phs->maxlen =3D sizeof(OCIXMLType*);
+    }
+    else
+	croak("Unsupported named object type for bind parameter");
+
+
+    /* bind by name */
+
+    OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
+			   (text*)phs->name, (sb4)strlen(phs->name),
+			   (dvoid *) NULL, /* value supplied in BindObject later */
+			   0,
+			   (ub2)phs->ftype, 0,
+			   NULL,
+			   0, 0,
+			   NULL,
+			   (ub4)OCI_DEFAULT,
+			   status
+			   );
+
+    if (status !=3D OCI_SUCCESS) {
+      oci_error(sth, imp_sth->errhp, status, "OCIBindByName SQLT_NTY");
+      return 0;
+    }
+    if (DBIS->debug >=3D 3)
+	PerlIO_printf(DBILOGFP, "    pp_rebind_ph_nty: END\n");
+
+
+    /* bind the object */
+
+    OCIBindObject(phs->bndhp, imp_sth->errhp,
+		  (CONST OCIType*)tdo,
+		  (dvoid **)&phs->progv,
+		  (ub4*)NULL,
+		  (dvoid **)NULL,
+		  (ub4*)NULL);
+
+    return 2;
+}
=20
 static int=20
 dbd_rebind_ph_char(sth, imp_sth, phs, alen_ptr_ptr)=20
@@ -1307,6 +1375,9 @@
     case SQLT_RSET:
 	    done =3D dbd_rebind_ph_rset(sth, imp_sth, phs);
 	    break;
+    case 108:
+	    done =3D dbd_rebind_ph_nty(sth, imp_sth, phs);
+	    break;
 #else
     case 102:	/* SQLT_CUR */
 	    done =3D dbd_rebind_ph_cursor(sth, imp_sth, phs);
@@ -1315,6 +1386,7 @@
     default:
 	    done =3D dbd_rebind_ph_char(sth, imp_sth, phs, &alen_ptr);
     }
+
     if (done !=3D 1) {
 	if (done =3D=3D 2) { /* the rebind did the OCI bind call itself successfu=
lly */
 	    if (DBIS->debug >=3D 3)
@@ -1328,7 +1400,7 @@
 #ifdef OCI_V8_SYNTAX
     if (phs->maxlen > phs->maxlen_bound) {
 	sword status;
-	int at_exec =3D (phs->desc_h =3D=3D NULL);
+	int at_exec =3D (phs->desc_h =3D=3D NULL) && (phs->ftype !=3D 108);
 	OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
 		(text*)phs->name, (sb4)strlen(phs->name),
 		phs->progv,
@@ -1416,8 +1488,9 @@
     }
     assert(name !=3D Nullch);
=20
-    if (SvROK(newvalue) && !IS_DBI_HANDLE(newvalue))
+    if (SvROK(newvalue) && (!IS_DBI_HANDLE(newvalue)) && (sql_type!=3DSQLT=
_NTY))
 	/* dbi handle allowed for cursor variables */
+	/* ref allowed for OCIXMLType* */
 	croak("Can't bind a reference (%s)", neatsvpv(newvalue,0));
     if (SvTYPE(newvalue) > SVt_PVLV) /* hook for later array logic?	*/
 	croak("Can't bind a non-scalar value (%s)", neatsvpv(newvalue,0));
@@ -2217,6 +2290,7 @@
 #ifdef OCI_V8_SYNTAX
     case SQLT_CLOB: sql_fbh.dbtype =3D SQL_CLOB;		break;
     case SQLT_BLOB: sql_fbh.dbtype =3D SQL_BLOB;		break;
+    case SQLT_NTY:  sql_fbh.dbtype =3D SQL_UDT;           break;
 #endif
 #ifdef SQLT_TIMESTAMP_TZ
     case SQLT_TIMESTAMP_TZ:  sql_fbh.dbtype =3D SQL_TIMESTAMP;	break;

--=-Sq1IOPDEhKoqxUKefiS3--



From timbo@dansat.data-plan.com  Fri Jan 30 18:32:30 2004
Received: from localhost (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0UIVK3f073353
	for <timbo@localhost>; Fri, 30 Jan 2004 18:32:30 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: from pop3.mail.demon.net [194.217.242.253]
	by localhost with POP3 (fetchmail-5.8.5)
	for timbo@localhost (single-drop); Fri, 30 Jan 2004 18:32:30 +0000 (GMT)
Received: from punt-3.mail.demon.net by mailstore
	for pobox@dbi.demon.co.uk id 1AmceP-000603-GP;
	Fri, 30 Jan 2004 17:41:53 +0000
Received: from [194.217.242.71] (helo=anchor-hub.mail.demon.net)
	by punt-3.mail.demon.net with esmtp id 1AmceP-000603-GP
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 17:41:53 +0000
Received: from [208.210.124.73] (helo=icicle.pobox.com)
	by anchor-hub.mail.demon.net with esmtp id 1AmceO-0006dQ-DB
	for pobox@dbi.demon.co.uk; Fri, 30 Jan 2004 17:41:52 +0000
Received: from icicle.pobox.com (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 25AEA3F13D
	for <pobox@dbi.demon.co.uk>; Fri, 30 Jan 2004 12:41:51 -0500 (EST)
Delivered-To: tim.bunce@pobox.com
Received: from colander (localhost [127.0.0.1])
	by icicle.pobox.com (Postfix) with ESMTP id 9FB863F16E
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 12:41:49 -0500 (EST)
Received: from mail09.svc.cra.dublin.eircom.net (mail09.svc.cra.dublin.eircom.net [159.134.118.25])
	by icicle.pobox.com (Postfix) with SMTP
	for <Tim.Bunce@pobox.com>; Fri, 30 Jan 2004 12:41:11 -0500 (EST)
Received: (qmail 9504 messnum 226571 invoked from network[213.94.228.233/unknown]); 30 Jan 2004 17:40:43 -0000
Received: from unknown (HELO dansat.data-plan.com) (213.94.228.233)
  by mail09.svc.cra.dublin.eircom.net (qp 9504) with SMTP; 30 Jan 2004 17:40:43 -0000
Received: from dansat.data-plan.com (localhost [127.0.0.1])
	by dansat.data-plan.com (8.12.9/8.12.9) with ESMTP id i0UHf33A072739;
	Fri, 30 Jan 2004 17:41:03 GMT
	(envelope-from timbo@dansat.data-plan.com)
Received: (from timbo@localhost)
	by dansat.data-plan.com (8.12.9/8.12.9/Submit) id i0UHf2Wr072738;
	Fri, 30 Jan 2004 17:41:02 GMT
Date: Fri, 30 Jan 2004 17:41:02 +0000
From: Tim Bunce <Tim.Bunce@pobox.com>
To: Hendrik Fuss <hendrik.fuss@morphochem.de>
Cc: Tim Bunce <Tim.Bunce@pobox.com>, "dbi-dev@perl.org" <dbi-dev@perl.org>
Subject: Re: DBD-Oracle and XMLType
Message-ID: <20040130174102.GB72657@dansat.data-plan.com>
References: <1075459292.7305.46.camel@mars> <20040130133443.GC70215@dansat.data-plan.com> <1075471263.7305.73.camel@mars>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
In-Reply-To: <1075471263.7305.73.camel@mars>
User-Agent: Mutt/1.4i
Status: RO
Content-Length: 1129
Lines: 29

On Fri, Jan 30, 2004 at 03:01:03PM +0100, Hendrik Fuss wrote:
> > > The attached patch (based on DBD-Oracle 1.15) enables you to upload
> > > XMLType objects (OCIXMLTypePtr) by binding them as SQLT_NTY. In dbdimp.c
> > > I added a function dbd_rebind_ph_nty for that purpose. You need to
> > > create that XMLType object first using the C function
> > > createxmlfromstring in xml.c.
> > 
> > I there any chance you could post that as a context diff (diff -u ideally
> > or else diff -c)? It's much safer and more useful. Thanks.
> 
> Good idea. Here's a diff -u of dbdimp.c.

Thanks.

> By the way: I have thougt about general support of named types, not just
> XMLType, but you need to get the type description (TDO) from somewhere.
> My code just checks if the perl variable is a blessed reference of
> "OCIXMLTypePtr".

Doing the equivalent of m/^OCI(\w+)Ptr$/ and then calling OCITypeByName
with $1 uppercased might take us (or someone) a step further.

> Also note that my code can't handle downloading of XMLType objects yet.

I'll trust that some kind soul with an itch will send a patch :-)

Thanks again Hendrik.

Tim.

