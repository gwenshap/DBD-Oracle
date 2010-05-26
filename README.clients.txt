This file contains some random notes relating to minimal Oracle
configurations for building and/or using DBD::Oracle / Oraperl.


*** ALL THE TEXT BELOW IS OLD ***
*** THE PREFERED METHOD IS TO USE Oracle Instant Client ***


-------------------------------------------------------------------------------
With recent versions of Oracle (specifically >= 7.3) you may be
able to build DBD::Oracle without Pro*C installed by using the Oracle
supplied oracle.mk file:

	perl Makefile.PL -m $ORACLE_HOME/rdbms/demo/oracle.mk

(The oracle.mk file might also be found in $ORACLE_HOME/rdbms/public/)

-------------------------------------------------------------------------------
From: James Cooper <pixel@coe.missouri.edu>

>      [...], what do I need in addition to perl5 to access an Oracle database 
>      on another system from a unix box (Solaris 2.5) that doesn't have an 
>      oracle database running on it ?
>      
>      In other words are their some oracle shared objects, etc. I need ?

I don't have experience with Solaris, but on IRIX 5.3, I simply installed
SQL*Net ($ORACLE_HOME/network/admin/*) and the OCI libraries which are in
$ORACLE_HOME/lib. You'll also need the header files from
$ORACLE_HOME/sqllib/public/*.h and $ORACLE_HOME/rdbms/demo/*.h (you won't
need them all, but you can get rid of them after DBD::Oracle compiles).

[You'll probably need at least ocommon in addition to network. But if you
use the Oracle installer (as you always should) it'll probably install
ocommon for you.]

So just put that stuff on your client box and install DBI and DBD::Oracle
there.  Once DBD::Oracle is installed you can remove the OCI libraries and
headers (make sure to keep SQL*Net!)

Other than that, getting it working isn't too hard.  If you're not
familiar with SQL*Net, let me know.  I'm no expert, but I know the basics.
The main thing is to have a good tnsnames.ora file in
$ORACLE_HOME/network/admin

-------------------------------------------------------------------------------
From: Jon Meek <meekj@Cyanamid.COM>

For my compilation of DBD-Oracle/Solaris2.5/Oracle7.2.x(x=2, I think), I
just pulled the required files in the rdbms directory from the Oracle CD.
The files I needed were:

$ ls -lR
drwxr-xr-x   2 oracle   apbr         512 May 15 17:43 demo/
drwxr-xr-x   2 oracle   apbr         512 May 15 16:20 lib/
drwxr-xr-x   2 oracle   apbr         512 May 15 16:18 mesg/
drwxr-xr-x   2 oracle   apbr         512 May 15 17:38 public/

./demo:
-r--r--r--   1 oracle   apbr        4509 Jun 29  1995 ociapr.h
-r--r--r--   1 oracle   apbr        5187 Jun 29  1995 ocidfn.h
-rw-rw-r--   1 oracle   apbr        6659 Jun 29  1995 oratypes.h

./lib:
-rw-r--r--   1 oracle   apbr        1132 Jul  6  1995 clntsh.mk
-rwxr-xr-x   1 oracle   apbr        5623 Jul 17  1995 genclntsh.sh*
-rw-r--r--   1 oracle   apbr       15211 Jul  5  1995 oracle.mk
-rw-r--r--   2 oracle   apbr        3137 May 15 16:20 osntab.s
-rw-r--r--   2 oracle   apbr        3137 May 15 16:20 osntabst.s
-rw-r--r--   1 oracle   apbr           9 May 15 16:19 psoliblist
-rw-r--r--   1 oracle   apbr          39 May 15 16:21 sysliblist

./mesg:
-r--r--r--   1 oracle   apbr      183296 Jul 11  1995 oraus.msb
-r--r--r--   1 oracle   apbr      878114 Jul 11  1995 oraus.msg

./public:
-r--r--r--   1 oracle   apbr        5187 Jun 29  1995 ocidfn.h

Jon

-------------------------------------------------------------------------------
Jon Meek <meekj@pt.Cyanamid.COM> Tue, 18 Feb 1997

This was for Oracle 7.2.2.3.0 (client side for DBD:Oracle build) and
SQL*net v2. I have heard that sqlnet.ora might not be needed.

ls -lR oracle
oracle:
total 2
drwxr-xr-x   3 meekj    apbr         512 Nov  3 11:46 network/

oracle/network:
total 2
drwxr-xr-x   2 meekj    apbr         512 Nov  3 11:46 admin/

oracle/network/admin:
total 6
-rw-r--r--   1 meekj    apbr         309 Nov  3 11:46 sqlnet.ora
-rw-r--r--   1 meekj    apbr        1989 Nov  3 11:46 tnsnames.ora

-------------------------------------------------------------------------------

From: Lack Mr G M <gml4410@ggr.co.uk>
Date: Thu, 23 Jan 1997 18:24:03 +0000

   I  noticed  the appended in the README.clients file of the DBD-Oracle
distribution.  My experience is somewhat different (and simpler).

   On Irix5.3 (ie.  what this user was using) I built DBI and DBD-Oracle
on a system with Oracle and Pro*C installed.  I  tested  it  on  another
system  (where I knew an oracle id).  I installed it from a third (which
had write rights to the master copies of the NFS  mounted  directories),
but this didn't have Oracle installed.

   Having  done  this  all  of  my systems (even those without a hint of
oracle on them) could access remote Oracle servers by  setting  TWO_TASK
appropriately.  SQL*Net didn't seem to come into it.

   The  dynamically-loadable library created (auto/DBD/Oracle/Oracle.so)
contains no reference to any dynamic Oracle library.

   Exactly the same happened for my Solaris systems.

 From: James Cooper <pixel@coe.missouri.edu>
 >      [...], what do I need in addition to perl5 to access an Oracle database
 >      on another system from a unix box (Solaris 2.5) that doesn't have an
 >      oracle database running on it ?
 >
 >      In other words are their some oracle shared objects, etc. I need ?

I don't have experience with Solaris, but on IRIX 5.3, I simply installed
SQL*Net ($ORACLE_HOME/network/admin/*) and the OCI libraries which are in
$ORACLE_HOME/lib. You'll also need the header files from
$ORACLE_HOME/sqllib/public/*.h and $ORACLE_HOME/rdbms/demo/*.h (you won't
need them all, but you can get rid of them after DBD::Oracle compiles).

So just put that stuff on your client box and install DBI and DBD::Oracle
there.  Once DBD::Oracle is installed you can remove the OCI libraries and
headers (make sure to keep SQL*Net!)

-------------------------------------------------------------------------------
OS/Oracle version: Solaris 2 and Oracle 7.3

Problem: DBD::Oracle works on the database machine, but not from remote
machines (via TCP).  SQL*Plus, however, does work from the remote machines.

Cause: $ORACLE_HOME/ocommon/nls/admin/data/lx1boot.nlb is missing

Solution: Make sure $ORACLE_HOME/ocommon is available on the remote machine.

This was the first time I had used DBD::Oracle with Oracle 7.3.2.  Oracle
7.1 has a somewhat different directory structure, and seems to store files
in different places relative to $ORACLE_HOME.  So I just hadn't NFS
exported all the files I needed to.  I figured that as long as SQL*Plus
was happy, I had all the necessary files to run DBD::Oracle (since that
was always the case with 7.1).  But I was wrong.

James Cooper <pixel@organic.com>

-------------------------------------------------------------------------------
Subject: Re: Oracle Licencing...
Date: Thu, 15 May 1997 11:54:09 -0700
From: Mark Dedlow <dedlow@voro.lbl.gov>

Please forgive the continuation of this somewhat off-topic issue,
but I wanted to correct/update my previous statement, and it's
probably of interest to many DBD-Oracle users.

> > In general, as I understand it, Oracle doesn't license the client runtime
> > libraries directly, rather they get you for SQL*NET.  It is typically
> > about $100 per node.  You have to have that licensed on any machine
> > that runs DBD-Oracle.

Oracle recently changed policy.  sqlnet now comes with RDBMS licenses.
If you have named RDBMS licenses, you can install sqlnet on as many
client machines as you have named licenses for the server.  If you
have concurrent RDBMS licenses, you can install sqlnet on as many
client machines as you like, and only use concurrently as many
as you have concurrent server RDBMS licenses.

OCI, Pro*C, et. al. only requires you to have a development license,
per developer.  The compiled apps can be distributed unlimited.
The client where the client app resides must be licensed to use
sqlnet, by the above terms, i.e. by virtue of what the licenses on
the server are that the client is connecting to.

This means one could legitimately distribute DBD-Oracle in compiled form.
Probably not recommended :-)

But is does mean one can compile DBD-Oracle and distribute it internally
to your org without more licensing, as long as the targets have sqlnet.

Obviously, this is not a legal ruling.  I don't work for Oracle.
But this is what my sales rep tells me as of today.

Mark
-------------------------------------------------------------------------------

From: Wintermute <wntrmute@gte.net>

Ok, you may think me daft for this but I just figured out what was
necessary in using DBI/DBD:Oracle on a machine that needs to access a
remote Oracle database.

What the docs tell you is that you just need enough of Oracle installed
to compile it.  They don't say that you need to keep that "just enough"
around for the DBI to work properly!!

So here's my predicament so that others might benefit from my bumbling.

I needed to install Perl, DBI, and DBD:Oracle on a machine running a
Fast Track web server (hostname Leviathan) that is to access a remote
Oracle database (henceforth called Yog-Sothoth (appropriate for the
beast that it is)).  Leviathan doesn't have enough space for the 500M
install that Oracle 7 for Solaris 2.5.1 wants so I had to figure out a
way to get things done. Here's a brief list of the steps I took for
Leviathan.

1. Got the GCC binary dist for Solaris 2.6 and installed
2. Got Perl 5.004_01 source/compiled/installed
3. Got the DBI .90 compiled/installed
4. Got DBD:Oracle...

                (and here's where it gets interesting).

        I exported the /opt/oracle7 directory from Yog-Sothoth to
Leviathan in
order to compile DBD:Oracle, then umount'ed it afterwards.  Tried 'make
test' after it had compiled and watched it flounder and fail.  For the
life of me I couldn't figure out why this could be so, so I went back
and adjusted my TWO_TASK/ORACLE_USERID env vars.
        No luck.
        Wash/Rinse/Repeat.
        Still no luck.
I started to get desperate about this time, so instead of screwing with
it anymore I installed the module under the Perl heirarchy just to be
done for the moment with it (figuring that the 'make test' script could
be fallible). I neglected to mention that the errors I was getting were
coming from the Oracle database on the remote machine, so I knew it
worked in part, just not well enough to hold the connection for some
reason.

After having no luck with my own Perl connect script I tried remounting
the nfs volume with Oracle on it and setting ORACLE_HOME to it.  When I
ran that very same Perl script it WORKED!  Well sort of.  None of the
short connection methods worked, I was forced to use the long method of
connecting IE: name/password@dbname(DESCRIPTION=(ADDRESS=(...etc.etc.

So here I am figuring that I'm doing something right, but there's
something I'm missing.  Well it turns out that it's not me, it's the
machine that's missing it.  If you are going to be using the DBD:Oracle
driver with DBI, you'll need more than just it after compile time,
you'll need some Oracle files as well.

(BTW I'm running Oracle 7.3.2.2.0)

You'll need everything in /var/opt/oracle (on the machine that houses
Oracle), as well as $ORACLE_HOME/ocommon/nls.  Why National Language
Support is needed I'll never know.  ocommon/nls has to reside under the
directory your $ORACLE_HOME points to, and it's best to leave
/var/opt/oracle/'s path alone.

When I made these adjustments on the Oracle'less box and tried the 'make

test' again, it ran through without a hitch.  I'll be doing some more
intensive things with it from here on out and if anything changes I'll
let you all know, however this seems odd that nothing is mentioned in
the documentation about what residual files need to be around after
compiling the DBD:Oracle for it to work successfully.

Like I said, don't flame me for being stupid, but I just had to get this
story off my chest since I've been puzzling over it all day and I feel
that other people may want to do the same thing as I did, and will run
into the same problems.

-- Wintermute

-------------------------------------------------------------------------------
