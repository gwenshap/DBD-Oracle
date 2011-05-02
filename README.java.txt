README.java.txt

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
    of the thread library. Note that this must be set before perl
    starts, you can't set it via $ENV{LD_PRELOAD} within the script.

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
appended a slight reworking of option 1 from Paul Vallee. And I've later
added some more useful messages from other people.

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

 - go to $ORACLE_HOME/network/lib (or it maybe (also?) in $ORACLE_HOME/oas/lib)
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

before starting any DBD::oracle app, the app works! (Note that this must
be set before perl starts, you can't set it via $ENV{LD_PRELOAD} within
the script.)

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

3. cd $ORACLE_HOME/network/lib (or it maybe (also?) in $ORACLE_HOME/oas/lib)
This is your new ORACLE_HOME - the temporary one that will soon be without
Java or Radius.

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

9. Test this out. I use the following command which fails
nicely if we've failed, and is very quiet if we've succeeded:
  perl -MDBD::Oracle -e 0
there should be no output. Congratulations.

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

From: Peter Ludemann <peter.ludemann@us.xacct.com>

Here's a different way for ensuring that LD_PRELOAD has been set:

  unless (($ENV{LD_PRELOAD}||'') =~ /thread.so/) {
    $ENV{LD_PRELOAD} = '/lib/libthread.so';
    exec($^X, '-w', $0, @ARGV);
  }

This hasn't been rigorously tested, but it seems to do the trick, at
least on Solaris 7 with Oracle 8.

------------------------------------------------------------------------------ 

From: VG <vgabriel@nbcs.rutgers.edu>

I've had luck with adding the following at the top of my program:

use DynaLoader;
Dynaloader::db_load_file("/usr/lib/libthread.so", 0x01);

(Others have reported this nor working for them.)

------------------------------------------------------------------------------ 

From: daver@despair.tmok.com (Dave C.)
Subject: Re: DBI::DBD with Oracle 8i
Newsgroups: comp.lang.perl.modules

It looks like a lot of people are having this problem....

I managed to solve it. I'm running Oracle 8.1.6, Solaris 8, Perl 5.6.0,
and the latest DBI/DBD modules.

I did some experimentation and discovered that the root of the problem
was that libclntsh.so was linking with nautab.o. For some reason,
nautab.o was linked with this RADIUS authentication (?) thing that was
calling into Java (even though I don't use that particular functionality.)

So, what I had to do was generate a libclntsh.so that linked with a
nautab.o that didn't require the radius (and thus the java). I then
forced the Oracle DBD to link with my library and installed it, and it
worked.

Here's the step-by-step:
 
To do this, first copy the "genautab" and "genclntsh" scripts to a
scratch directory. By default "genautab" apparently generates some
default network authentication stub without a lot of options (which was
okay for me.)

I ran:
 
 ./genautab >nautab.s
 as -P nautab.s
 
After this step you should have a "nautab.o" file.
 
Now, you must must modify "genclntsh" to produce your custom clntsh
library (which I called "perlclntsh" so I wouldn't mess up the original
Oracle library.) So I went into the file and modified CLNT_NAM to read
"perlclntsh".  I also changed LIB_DIR to put the resulting library in
my current directory:  (LIB_DIR=`pwd`)

Also, instead of creating the library, I modified the script to just
echo the command. Search for "# Create library" and put "echo " before
{$LD} ${LD_RUNTIME}...  Now, when you run "./genclntsh" you should get
a large command. Redir this command to a file "./genclntsh >t"

Now, edit this file and remove all references to java libraries (get
rid of all "-ljava" instances, at least, and you may need to delete
other stuff, like -lnative_threads.) . Run your script: "sh ./t".
After some time you should wind up with a "libperlclntsh.so.8.0".
This is your custom library any of the java stuff linked in.

Then copy this lib to /usr/local/lib and create a softlink
"libperlclntsh.so" to "libperlclntsh.so.8.0" (or copy it wherever you
want...)

Then you have to force DBD to link with this library instead of linking
with the libclntsh.so provided by Oracle.

Basically what I did was follow the normal DBD-Oracle directions. I
then edited the resulting Makefile manually and changed all references
of libclntsh.so to libperlclnt.so (ie, -lclntsh to -lperlclntsh)  I
also changed the LDDLFLAGS and LDFLAGS and appended "-L/usr/local/lib
-R/usr/local/lib -L/usr/ucblib -R/usr/ucblib -lucb". (for some reason
the resulting DBD wanted to link with ucb) Run "make" and rebuild the
DBD.  Now "make test" should pass.

Note that this was a fairly long (couple of hours) series of trial and
error before I finally got this to work. Your system may be different
and you may encounter your own linking problems, etc.

Disclaimer: This may not work for you, but it worked for me. Even if it
does work for you there is no guarantee that the resulting module will
function correctly and won't hose your database, etc...

I forgot to mention that in script resulting from genclntsh you must
tell it to use _your_ nautab.o for linking, not the oracle lib one.
Oops.

-Dave

