README.java

This file relates to a specific problem on Solaris platforms
for Oracle 8.1.6 (and possibly later versions) where loading
DBD::Oracle fails with an error message like:

  ``You must install a Solaris patch to run this version of
    the Java runtime.
    Please see the README and release notes for more information.''

The problem seems to be that:

1/  By default, the Oracle shared library contains a ``Radius
    authentication module'' that is implemented in Java.
2/  The Java implementation requires that the thread library is
    also linked into the application.
3/  For some inexplicable reason the thread library has to be
    linked to the executable that's doing the dynamic loading.
    It's is not sufficient to link -lthread to DBD::Oracle.

There are several ways to workaround this:

1/  Remove the Radius authentication module if you don't need it.
    This requires you to perform surgery on the Oracle installation.
    (If the name Radius doesn't mean anything to you and you're
    the person maintaining the Oracle installation then you almost
    certainly don't need it.)

2/  Use the LD_PRELOAD environment variable to force the pre-loading
    of the thread library.

3/  Link the thread library to your perl binary.
    You can do that either by (re)building perl with thread support
    or, I believe, it should be possible to issue a magic 'ld' command
    to add linkage to the thread library to an existing perl executable.
    (But you'll need to work that one out yourself. If you do please let
    me know so I can add the details here to share with others.)

Most of this information comes from Andi Lamprecht, to whom I'm very
grateful indeed.

I've included below two of his email messages, slightly edited, where
he explains the procedure for options 1 and 2 above. I've also
appended a slight reworking of option 1 from Paul Vallee.

Tim.

----


From: andi@sunnix.sie.siemens.at

Have managed it to get DBD to work with Oracle 8i without these nasty Java
error! It seems to be that a thing called "NAU" links in a radius
athentication module which is written in Java and this causes the
additional java libraries in the libclntsh.so. After throwing it all out
DBD tests ran successfully.

The steps to take are:

 - shut down Oracle server if you have one running in the installation
   you're about to modify.
 - take a backup copy of your Oracle installation! You have been warned!

 - go to $ORACLE_HOME/network/lib
 - rebuild nautab.o with:

     make -f ins_nau.mk NAU_ADAPTERS="IDENTIX KERBEROS5 SECURID" nautab.o

   This build a new nautab.o without the radius authentication module.

 - go to $ORACLE_HOME/lib
 - edit file "ldflags" and delete all occurences of "-lnrad8" and "-ljava"
   and "-[LR]$ORACLE_HOME/JRE/lib/sparc/native_threads"

 - go to $ORACLE_HOME/bin
 - build a new libclntsh.so with:

     genclntsh

 - start up Oracle

 - go back to the DBD-* directory and build the Oracle driver with:

     perl Makefile.PL; make; make test

This worked for me, the database is still operational, MAYBE SOME JAVA
STUFF ISN'T WORKING. Better someone else with more experience in java
finds out ...

The problem seems to be a dynamic linking issue. Whenever java virtual
machine is loaded, some symbols are missing (with java 1.2.2_05 these
_thread_something symbols where not found, even with linked-in
libthread.so, with java 1.1.8 some _lseek or so symbols couldn't be
resolved). Seems Oracle did a good job in integration of Java in the
database ...

Ok, should go out now 'cause its a beatiful wheater here in Vienna!

Greetings
A. Lamprecht

-----------


From: andi@sunnix.sie.siemens.at

For some reason libthread.so.1 isn't included as dynamic object in perl
binary and so symbols aren't found.

The interesting output of LD_DEBUG=symbols:
symbol=thr_getstate;  dlsym() starting at file=/usr/local/bin/perl 
symbol=thr_getstate;  lookup in file=/usr/local/bin/perl  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libsocket.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libnsl.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libdl.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libm.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libc.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libcrypt_i.so.1  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libmp.so.2  [ ELF ]
symbol=thr_getstate;  lookup in file=/lib/libgen.so.1  [ ELF ]
ld.so.1: /usr/local/bin/perl: fatal: thr_getstate: can't find symbol

This list looks exactly like the one you get when ldd-ing the perl binary.
There is an option to the dynamic linker "LD_PRELOAD" and if you set it with

 LD_PRELOAD=/lib/libthread.so.1
 export LD_PRELOAD

before starting any DBD::oracle app, the app works!

It looks like after libjava and libjvm is loaded, the library search path
is somehow stripped to the one of the perl binary ...

[That looks like a Solaris bug]

Hope this helps.

A. Lamprecht
-----------


From: Paul Vallee <vallee+dbi@pythian.com>

Andi is right. Three cheers for Andi!!! :-)

Final Summary (this is mostly Andi's work summarized here)

1. Copy your ORACLE_HOME in it's entirety to a new directory.
cp -r $ORACLE_HOME $ORACLE_HOME.nojava
2. Set your ORACLE_HOME variable to the new one. Save the old one for reference.
export OLD_ORACLE_HOME=$ORACLE_HOME
export ORACLE_HOME=$ORACLE_HOME.nojava
3. cd $ORACLE_HOME/network/lib
(This is your new ORACLE_HOME - the temporary one that will soon be without
Java or Radius)
4. build nautab.o with
make -f ins_nau.mk NAU_ADAPTERS="IDENTIX KERBEROS5 SECURID" nautab.o
5. go to $ORACLE_HOME/lib
edit file "ldflags" and delete all occurences of "-lnrad8" and "-ljava"
and "-[LR]$ORACLE_HOME/JRE/lib/sparc/native_threads"
I wrote this little pipeline to do this.
sed 's/-lnrad8//g' < ldflags | \
sed 's/-ljava//g' | \
sed "s%-L$OLD_ORACLE_HOME/JRE/lib/sparc/native_threads%%g" | \
sed "s%-R$OLD_ORACLE_HOME/JRE/lib/sparc/native_threads%%g" | > newldflags
If you look at newldflags, and like it, then run:
cp ldflags oldldflags; cp newldflags ldflags
6. go to $ORACLE_HOME/bin and build a new libclntsh.so with "genclntsh"
genclntsh
7. go to your DBD::oracle install directory and go through the regular
install process.
perl Makefile.PL; make; make install
(I find the make test less useful than my test.pl perl file.)
8. Set LD_LIBRARY_PATH=$ORACLE_HOME/lib.
This part is very important - remember that at this stage ORACLE_HOME is set
to the nojava home. Make this permanent by explicitly setting
LD_LIBRARY_PATH to the nojava lib directory in your .profile.
This is the step that stalled me - thanks again to Andi.
9. Test this out. I use the following, which I call test.pl, which fails
nicely if we've failed, and is very quiet if we've succeeded:
#!/usr/bin/perl
use strict;
use DBI;
use DBD::Oracle;
0;
./test.pl should have no output. Congratulations.
10. Get rid of everything other than libclntsh.so in your new ORACLE_HOME -
the rest is a waste of space.
cd $ORACLE_HOME; cd ..
mv $ORACLE_HOME $ORACLE_HOME.rmme
mkdir $ORACLE_HOME; mkdir $ORACLE_HOME/lib
cp $ORACLE_HOME.rmme/lib/libclntsh.so $ORACLE_HOME/lib
11. Run test.pl again just to be sure it still works.
12. If test.pl is still working, then we can reclaim space with
rm -fr $ORACLE_HOME.rmme

Note that in my opinion this is a workaround - there is no reason on the
face of it that I can fathom that we shouldn't be able to use DBD::Oracle to
connect to Oracle with Java compiled in. (?)

Enjoy,
Paul Vallee
Principal
The Pythian Group, Inc.
------------------------------------------------------------------------------ 

