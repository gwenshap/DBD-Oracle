From dbi-users-bounce@isc.org  Tue May 16 22:53:12 2000
Return-Path: <dbi-users-bounce@isc.org>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id WAA29547; Tue, 16 May 2000 22:53:11 +0100
Received: from finch-punt-12.mail.demon.net by oink with SMTP (PP) 
          id <04730-2@oink>; Sat, 16 May 1970 22:51:48 +0100
Received: from punt-1.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 958512876:10:15786:0; Tue, 16 May 2000 21:34:36 GMT
Received: from pub3.rc.vix.com ([204.152.186.34]) by punt-1.mail.demon.net 
          id aa1122388; 16 May 2000 21:33 GMT
Received: from pub3.rc.vix.com (pub3.rc.vix.com [204.152.186.34]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id 661E53EC8;
          Tue, 16 May 2000 14:33:38 -0700 (PDT)
Received: with LISTAR (v0.129a; list dbi-users);
          Tue, 16 May 2000 14:28:31 -0700 (PDT)
Received: from isrv3.isc.org (isrv3.isc.org [204.152.184.87]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id 7192F3E20 
          for <dbi-users@pub3.rc.vix.com>;
          Tue, 16 May 2000 14:28:27 -0700 (PDT)
Received: from anchor-post-34.mail.demon.net (anchor-post-34.mail.demon.net [194.217.242.92]) 
          by isrv3.isc.org (8.9.1/8.9.1) via ESMTP id OAA27204 
          for <dbi-users@isc.org>;
          Tue, 16 May 2000 14:28:26 -0700 (PDT) env-from (Tim.Bunce@ig.co.uk)
Received: from ignite.demon.co.uk ([158.152.8.99] helo=oink) 
          by anchor-post-34.mail.demon.net with smtp (Exim 2.12 #1) 
          id 12rot7-000Mp4-0Y; Tue, 16 May 2000 22:28:25 +0100
Received: from toad by oink with SMTP (PP) id <04650-0@oink>;
          Sat, 16 May 1970 22:23:55 +0100
Received: by toad.ig.co.uk (SMI-8.6/SMI-SVR4) id WAA29289;
          Tue, 16 May 2000 22:23:50 +0100
Date: Tue, 16 May 2000 22:23:50 +0100
From: Tim Bunce <Tim.Bunce@ig.co.uk>
To: peter_dev@talk21.com
Cc: dbi-users@isc.org
Subject: Re: Oracle Stored Procs take longer than embedded SQL
Message-ID: <20000516222350.F28435@ig.co.uk>
References: <20000516174946.QLKD22548.t21mta02-app.talk21.com@t21mtaV-lrs>
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.3i
In-Reply-To: <20000516174946.QLKD22548.t21mta02-app.talk21.com@t21mtaV-lrs>; from peter_dev@talk21.com on Tue, May 16, 2000 at 06:48:22PM +0100
Organization: Paul Ingram Group, Software Systems, +44 1 483 862800
Sender: dbi-users-bounce@isc.org
Errors-To: dbi-users-bounce@isc.org
X-original-sender: Tim.Bunce@ig.co.uk
Precedence: bulk
List-unsubscribe: <mailto:dbi-users-request@isc.org?Subject=unsubscribe>
X-List-ID: <dbi-users.isc.org>
List-owner: <mailto:dbi-users-admins@isc.org>
List-post: <mailto:dbi-users@isc.org>
Status: RO
Content-Length: 1372
Lines: 30

On Tue, May 16, 2000 at 06:48:22PM +0100, peter_dev@talk21.com wrote:
> I have a problem with the fetching of data from an Oracle Ref Cursor taking longer than the same query in Embeded SQL.
> 
> $ get_sp.pl
> Fetched in 0.00774896144866943 seconds
> Completed in 0.106827020645142 seconds
> 
> $ get_sql.pl
> Fetched in 0.00138604640960693 seconds
> Completed in 0.380790948867798 seconds
> 
> In this example (Using the SCOTT/TIGER tables), while the Stored Procedure completed first, the actual fetch of the data took considerably longer. In a real situation (e.g. bigger tables ), this is easily the longest part of the task and causes the overall execution time to increase hugely.
> 
> Any Help would be appreciated 
> thanks

Possibly related to the lack of a row cache on that statement handle.
You, or some kind volunteer, could probably hack that in without too
much work.

Tim.


------------------------------------------------------------------------------
DBI HOME PAGE AND ARCHIVES: http://www.symbolstone.org/technology/perl/DBI/
To unsubscribe from this list, please visit: http://www.isc.org/dbi-lists.html
If you are without web access, or if you are having trouble with the web page, 
please send mail to dbi-users-request@isc.org with the subject line of:
'unsubscribe'.
------------------------------------------------------------------------------ 

