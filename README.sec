I have no intention of becoming a channel for Oracle Support Services
but this is a significant security hole and so I'm making an exception.

----- Forwarded message from Oracle Support Services <MEDIAGRP@US.ORACLE.COM> -----

Date: Fri, 7 May 1999 06:29:09 -0700
From: Oracle Support Services <MEDIAGRP@US.ORACLE.COM>
Subject: SUID Security Issue

Platform:		UNIX

Distribution:  		Internal & External

Problem Subject Line:   SUID Security

Product: 		Oracle Enterprise Manager 2.0.4
                        Oracle Data Server

Oracle Version:		8.0.3, 8.0.4, 8.0.5, 8.1.5 

Component:		Intelligent Agent
                        Oracle Data Server

Component Version:	8.0.3, 8.0.4, 8.0.5, 8.1.5

Sub-Component:		N/A

Platform Version: 	All Unix Versions.

Errors:			N/A

Revision Date:		6-March-1999   

Problem Description:

On UNIX platforms, some executable files have the setuid (SUID)
bit on.  It may be possible for a knowledgeable user to use 
these executables to bypass your system security by elevating 
their operating system privileges.   Oracle Corporation has 
identified issues regarding executables with SUID set in 
Oracle releases 8.0.3, 8.0.4, 8.0.5 and 8.1.5 on UNIX platforms 
only.  This problem will be fixed in Oracle releases 8.0.6 and 
8.1.6.

Depending on your Oracle installation, the available patch will 1)
correct the SUID bits on applicable files, and/or 2) delete the
oratclsh file.  This shell script should be run immediately, and also
should be run after each relink of Oracle.

You can download the patch from Oracle Support?s MetaLink website by
going to the following URL,
http://support.oracle.com/ml/plsql/mlv15.frame?call_type=download&javaFlag=JAVA.
Once you are in this page, select 'Oracle RDBMS' as the product
and then click on the 'Go' button.  Then download patch named 'setuid.'

Please contact Oracle Worldwide Support for any additional issues.

----- End forwarded message -----

Date: Sat, 08 May 1999 19:12:52 -0700
From: Mark Dedlow <dedlow@voro.lbl.gov>

I went to the URL listed for the patch, but it appears you can't get to
it directly.  It requires a Oracle Metalink account, and even then, you
have to follow a bunch of links to get it, you can't go direct (at
least I couldn't at the URL in the announcement).

You don't really need the patch however, it's just a shell script that
in effect does chmod -s on everything in $ORACLE_HOME/bin except
'oracle' and 'dbsnmp' (needed only for OEM or SNMP).

Also, although the patch didn't address the issue, make sure _nothing_
below ORACLE_HOME is owned by root.  There are some installations that
make certain files setuid to root (files that are trivial to compromise).

Mark


------------------------------------------------------------------------------

From: Dan Sugalski <sugalskd@osshe.edu>
Date: Mon, 10 May 1999 09:13:28 -0700

The patch actually removes the setuid bit on a number of oracle
executables. The 'unset' list is:

lsnrctl oemevent onrsd osslogin tnslsnr tnsping trcasst trcroute cmctl
cmadmin cmgw names namesctl otrccref otrcfmt otrcrep otrccol oracleO

While the 'must set' list is:

oracle dbsnmp

The shell script to fix the bits properly was posted to the oracle list
running at telelists.com. Check the archives there for it if you want.
(www.telelists.com) I think it's also gone out to one of the BUGTRAQ
lists, and some of the CERTs might have it too.

					Dan

------------------------------------------------------------------------------

Date: Wed, 12 May 1999 11:49:45 -0700
From: Mark Dedlow <dedlow@voro.lbl.gov>

> The patch actually removes the setuid bit on a number of oracle
> executables. The 'unset' list is:
> 
> lsnrctl oemevent onrsd osslogin tnslsnr tnsping trcasst trcroute cmctl
> cmadmin cmgw names namesctl otrccref otrcfmt otrcrep otrccol oracleO

Actually, there's a little more than that.  For each item in that list,
it also looks for a version of the file with a 0 or O appended to it
(these are backups the link makefiles create), so the above list isn't
exactly complete.

The important issues are simply:

  o *ONLY* $ORACLE_HOME/bin/oracle requires setuid bit set for 
    the Oracle RDBMS and tools to function.

  o *IF* you run dbsnmp, it must be setuid. (If you don't know what dbsnmp
    is, you're probably not running it -- it's a remote monitoring/control
    daemon)

Armed with that knowledge, you can use any technique you like to achieve
the desired results.  For example, this achieves it:
  
find $ORACLE_HOME/bin -perm -2000 ! -name oracle ! -name dbsnmp | xargs chmod -s

Mark

------------------------------------------------------------------------------

One further note I'll pass on anonymously and without comment:

> please include something like: "After removing the setuid bits, slap
> your system administrator for running root.sh as root without actually
> reading it first."
> :)

------------------------------------------------------------------------------
