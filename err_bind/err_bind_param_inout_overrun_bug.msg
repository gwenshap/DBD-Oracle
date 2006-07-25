From dbi-users-return-215-Tim.Bunce=ig.co.uk@perl.org  Mon Feb  5 23:03:29 2001
Return-Path: <dbi-users-return-215-Tim.Bunce=ig.co.uk@perl.org>
Received: from oink by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id XAA01289; Mon, 5 Feb 2001 23:03:27 GMT
Received: from tele-punt-22.mail.demon.net by oink with SMTP (PP) 
          id <06769-16@oink>; Fri, 6 Feb 1970 00:01:15 +0100
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 981413584:20:24069:0; Mon, 05 Feb 2001 22:53:04 GMT
Received: from tmtowtdi.perl.org ([209.85.3.25]) by punt-2.mail.demon.net 
          id aa2024004; 5 Feb 2001 22:53 GMT
Received: (qmail 6267 invoked by uid 508); 5 Feb 2001 22:52:23 -0000
Mailing-List: contact dbi-users-help@perl.org; run by ezmlm
Precedence: bulk
List-Post: <mailto:dbi-users@perl.org>
List-Help: <mailto:dbi-users-help@perl.org>
List-Unsubscribe: <mailto:dbi-users-unsubscribe@perl.org>
List-Subscribe: <mailto:dbi-users-subscribe@perl.org>
Delivered-To: mailing list dbi-users@perl.org
Received: (qmail 6247 invoked from network); 5 Feb 2001 22:52:22 -0000
Received: from seeme.dare.feddata.com (38.186.101.66) by tmtowtdi.perl.org 
          with SMTP; 5 Feb 2001 22:52:22 -0000
Received: by seeme.dare.feddata.com; id OAA05466;
          Mon, 5 Feb 2001 14:55:56 -0800 (PST)
Received: from ifyou.dare.feddata.com(38.186.101.111) by seeme.dare.feddata.com 
          via smap (4.1) id xma005448; Mon, 5 Feb 01 14:55:39 -0800
Sender: oscar@dare.feddata.com
Message-ID: <3A7F2FB0.A1507582@pasadena.feddata.com>
Date: Mon, 05 Feb 2001 14:56:48 -0800
From: Oscar DeMartino <fdemartino@pasadena.feddata.com>
Organization: Federal Data Corporation
X-Mailer: Mozilla 4.61 [en] (X11; U; SunOS 5.6 sun4u)
X-Accept-Language: en
MIME-Version: 1.0
To: dbi-users@perl.org
Subject: Undetected error - Binding and Stored Procedures
Content-Type: multipart/alternative; 
              boundary="------------E1028F7A8304BE268EB8F67B"
Status: RO
Content-Length: 2042
Lines: 66

--------------E1028F7A8304BE268EB8F67B
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

I am running Oracle 8.1.5 and am using many stored procedures.  We
use returned cursors, and individual values.  The problem is, when
a stored procedure is executed and the specified bound variable has not
be declared large enough to hold the returned value subsequent
bound variables do not get set and I cannot find any way to
automatically detect this.

Example:

The stored procedure takes 1-input value and returns three string
values.

the stored procedure is prepared , so I get the statement handle.

I bind the input variable, and then bind the three output variables (1,
2, & 3)
as 100 character strings.

I then execute the statment handle.

There do not appear to be any errors, after checking the returned value
(for the execute call),
and ->err and ->errstr are clean.

variable 1 has the correct returned value.
BUT, output variable 2 & 3, have no value.

------
Executing the stored procedure using sqlplus (sql command line
interface) indicated:

What really occured is that the returned output variables 1 & 3 were
under 100 characters long
output variable 2 was 120 characters long

---------

I know I could make all output variables the max size allowed in the
database field
but this would seem to waste space in the perl code.  Since the field in

the database
is simply defined as a varchar2 with no size limitation (upto 32767).

-----
Am I missing something about detecting that variables 2 & 3 did not get
stored correctly
by DBI::Oracle??



--
Oscar "Fred" DeMartino                            FFFFF  DDDD    CCC
320 N. Halstead Ave. Ste #160                     F       D  D  C   C
Pasadena, CA 91107                                FFF     D  D  C
e-mail:   Oscar.DeMartino@pasadena.feddata.com    F       D  D  C
Phone:    (626)306-6649                           F       D  D  C   C
Federal Data Corporation                          F      DDDD    CCC



--------------E1028F7A8304BE268EB8F67B--

