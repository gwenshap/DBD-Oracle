From dbi-users-bounce@isc.org  Thu Sep 21 20:27:21 2000
Return-Path: <dbi-users-bounce@isc.org>
Received: from oink by toad.ig.co.uk (8.8.8+Sun/SMI-SVR4)
	id UAA18945; Thu, 21 Sep 2000 20:27:20 +0100 (BST)
Received: from tele-punt-22.mail.demon.net by oink with SMTP (PP) 
          id <02709-1@oink>; Mon, 21 Sep 1970 20:26:40 +0100
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 969564156:20:26825:1; Thu, 21 Sep 2000 19:22:36 GMT
Received: from pub3.rc.vix.com ([204.152.186.34]) by punt-2.mail.demon.net 
          id aa2026778; 21 Sep 2000 19:22 GMT
Received: from pub3.rc.vix.com (pub3.rc.vix.com [204.152.186.34]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id 28A613E5D;
          Thu, 21 Sep 2000 12:22:17 -0700 (PDT)
Received: with LISTAR (v1.0.0; list dbi-users);
          Thu, 21 Sep 2000 12:17:37 -0700 (PDT)
Received: from isrv3.isc.org (isrv3.isc.org [204.152.184.87]) 
          by pub3.rc.vix.com (Postfix) with ESMTP id A59853E42 
          for <dbi-users@pub3.rc.vix.com>;
          Thu, 21 Sep 2000 12:17:32 -0700 (PDT)
Received: from wheel.cs.wisc.edu (wheel.cs.wisc.edu [128.105.121.12]) 
          by isrv3.isc.org (8.9.1/8.9.1) via ESMTP id MAA00855 
          for <dbi-users@isc.org>;
          Thu, 21 Sep 2000 12:17:32 -0700 (PDT) env-from (horn@wheel.cs.wisc.edu)
Received: (from horn@localhost) by wheel.cs.wisc.edu (8.9.2/8.9.2) id OAA16413 
          for dbi-users@isc.org; Thu, 21 Sep 2000 14:17:28 -0500 (CDT)
Date: Thu, 21 Sep 2000 14:17:28 -0500 (CDT)
From: Jeffrey Horn <horn@cs.wisc.edu>
Message-Id: <200009211917.OAA16413@wheel.cs.wisc.edu>
To: dbi-users@isc.org
Subject: Setting ORA_TYPE after the fact...
Sender: horn@wheel.cs.wisc.edu
Sender: dbi-users-bounce@isc.org
Errors-To: dbi-users-bounce@isc.org
X-original-sender: horn@cs.wisc.edu
Precedence: bulk
List-unsubscribe: <mailto:dbi-users-request@isc.org?Subject=unsubscribe>
X-List-ID: <dbi-users.isc.org>
List-owner: <mailto:dbi-users-admins@isc.org>
List-post: <mailto:dbi-users@isc.org>
Status: RO
X-Status: A
Content-Length: 969
Lines: 20

I have a situation where I would like to return a cursor that contains a
CLOB as one of it's attributes from a PL/SQL procedure.  What I get back is
a LOB locator and DBD doesn't actually read the CLOB but instead returns an
error.

If I go through a bind/prepare/execute/fetch on a similar SQL statement all
is well.  Is there any way that I can tell DBD that a given attribute of
a cursor is a CLOB once the cursor is already opened so that DBD will do the
right thing?

-- Jeff Horn


------------------------------------------------------------------------------
DBI HOME PAGE AND ARCHIVES: http://www.symbolstone.org/technology/perl/DBI/
To unsubscribe from this list, please visit: http://www.isc.org/dbi-lists.html
If you are without web access, or if you are having trouble with the web page, 
please send mail to dbi-users-request@isc.org with the subject line of:
'unsubscribe'.
------------------------------------------------------------------------------ 

