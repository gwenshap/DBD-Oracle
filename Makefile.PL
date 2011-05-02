
##
##  You should not need to edit this file.
##

BEGIN { $^W = 1 }
BEGIN { require 5.004 }

use ExtUtils::MakeMaker 5.16, qw(&WriteMakefile $Verbose);
use Getopt::Long;
use Config;
use Cwd;
use File::Find;
use strict;

# This DBI must be installed before we can build a DBD.
# For those not using Dynamic loading this means building a
# new static perl in the DBI directory by saying 'make perl'
# and then using _that_ perl to make this one.
use DBI 1.20;
use DBI::DBD;	# DBD creation tools


# Some MakeMaker's forged some FileHandle methods
require FileHandle unless defined(&FileHandle::new);

BEGIN { if ($^O eq 'VMS') {
    require vmsish;
    import  vmsish;
    require VMS::Filespec;
    import  VMS::Filespec;
}}


my $dbi_dir      = dbd_dbi_dir();
my $dbi_arch_dir = dbd_dbi_arch_dir();
my $os = $^O;
my $osvers = $Config{osvers}; $osvers =~ s/^\s*(\d+\.\d+).*/$1/; # drop sub-sub-version: 2.5.1 -> 2.5
my $exe_ext = ($os eq 'VMS') ? '.pl' : '';
my $BELL = "\a";
$| = 1;

my %opts = (
    NAME => 'DBD::Oracle',
    VERSION_FROM => 'Oracle.pm',
    EXE_FILES => [ "ora_explain$exe_ext" ],
    OBJECT => '$(O_FILES)',
    DEFINE => '',
    DIR  => [],
    clean => {	FILES	=> 'Oracle.xsi dll.base dll.exp sqlnet.log libOracle.def ora_explain mk.pm' },
    dist  => {
	DIST_DEFAULT	=> 'clean distcheck disttest ci tardist',
	PREOP		=> '$(MAKE) -f Makefile.old distdir',
	COMPRESS	=> 'gzip -v9', SUFFIX => 'gz',
    },
);
if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR} = 'Tim Bunce (dbi-users@perl.org)';
    $opts{ABSTRACT_FROM} = 'Oracle.pm';
    $opts{PREREQ_PM} = { DBI => 0 };
    $opts{CAPI} = 'TRUE' if $Config{archname} =~ /-object\b/i;
}

$opts{LINKTYPE} = 'static' if $Config{dlsrc} =~ /dl_none/;

my(@MK, %MK, $MK_TEXT, %MK_expanding);	# parsed macros from Oracle's makefiles
my %mk_target_deps;
my %mk_target_rules;

# Options (rarely needed)
# to turn off an option prefix with 'no', ie 'perl Makefile.PL -nob'
$::opt_b = 1;	# try to use Oracle's own 'build' rule
$::opt_m = 0;	# path to proc.mk or oracle.mk file to read
$::opt_p = '';	# alter preference for oracle.mk over proc
$::opt_n = '';	# Oracle .mk macro name to use for library list to link with
$::opt_c = 0;	# don't encourage use of shared library
$::opt_l = 0;	# try direct-link to libclntsh
$::opt_g = '';	# enable debugging (-g for compiler and linker)
$::opt_s = '';	# Find a symbol in oracle libs, Don't build a Makefile
$::opt_S = '';	# Find a symbol in oracle & system libs, Don't build a Makefile
$::opt_v = 0;	# be more verbose
$::opt_d = 0;	# much more verbose for debugging
$::opt_8 = 0;	# disable use of OCI 8 (where available)
$::opt_f = 0;	# include text of oracle's .mk file within generated Makefile
$::opt_F = 0;	# force - ignore errors
$::opt_W = 0;	# just write a basic default Makefile (won't build)

Getopt::Long::config( qw( no_ignore_case ) );
GetOptions(qw(b! v! d! g! p! l! c! 8! f! F! W! m=s n=s s=s S=s))
	or die "Invalid arguments";

$::opt_g &&= '-g';	# convert to actual string
$::opt_v = 1 if $::opt_d;
$Verbose = 1 if $::opt_v;
my $is_me = (-d "/home/timbo/dbi" && ($ENV{LOGNAME}||'') eq 'timbo'); # a reasonable guess

if ($::opt_W) {
    open(MK_PM, ">/dev/null") or die "Unable to create mk.pm: $!";
    exit WriteMakefile( dbd_edit_mm_attribs(\%opts) )
}

# --- Introduction

print "\n Configuring DBD::Oracle ...\n
>>>\tRemember to actually *READ* the README file!
   \tEspecially if you have any problems.\n
" unless $::opt_s;


# --- Where is Oracle installed...

my $ORACLE_ENV  = ($os eq 'VMS') ? 'ORA_ROOT' : 'ORACLE_HOME';

my $OH = $ENV{$ORACLE_ENV} || '';
$OH  = win32_oracle_home($OH) if ($os eq 'MSWin32') or ($os =~ /cygwin/i);
($OH = unixify $OH) =~ s:/$:: if $os eq 'VMS';

die qq{  The $ORACLE_ENV environment variable must be set.
  It must be set to hold the path to an Oracle installation directory
  on this machine (or a machine with a compatible architecture).
  See the README.clients file for more information.
  ABORTED!
} unless $OH;

die qq{  The $ORACLE_ENV environment variable value ($OH) is not valid.
  It must be set to hold the path to an Oracle installation directory
  on this machine (or a compatible archtecture).
  See the README.clients file for more information.
  ABORTED!
} unless (($os eq 'VMS') ? -d $OH : -d "$OH/lib/.");

print "Using Oracle in $OH\n";

# We'll try to dig up some Oracle version information. Not essential.
my (@inspdver, %inspdver); $inspdver{RDBMS} = 0;
if ($os ne 'VMS' and $os ne 'MSWin32' and -x "$OH/orainst/inspdver") {
    open INST, "$OH/orainst/inspdver |";
    my @inspdver = <INST>;
    close INST;
    foreach (@inspdver) {
	chop;
	$inspdver{$2}    = $1 if m/^(\S+)\s+(.*)/;
	$inspdver{RDBMS} = $1 if m/^(\d+\.\d+\.\d+)\S*\s+.*RDBMS/;
	next unless $::opt_v
	    or 	m/RDBMS/i	or m/PL.SQL/i

	    or 	m/Precomp/i	or m/Pro\*C/i;
	print "$_\n";
    }
    print "\n";
    if ($inspdver{RDBMS} =~ /^7.3.[12]/ and $os eq 'hpux') {
	print "*** DBD::Oracle for Oracle $inspdver{RDBMS} on HP-UX may not build ok.\n";
	print "*** If your have problems read the README (in fact, read it anyway!)\n";
	print "*** An upgrade to at least Oracle 7.3.3 is probably a good idea.\n";
	sleep 5;
    }
}
# hack up a simple floating point form of the version: 8.1.6 => 8.106
($inspdver{rdbms_ver} = $inspdver{RDBMS}) =~ s/^(\d+\.\d+)\.(\d+)/${1}0$2/;


my @h_dirs = find_headers();
unless (@h_dirs) {
    print "I can't find the header files I need in your Oracle installation.\n";
    print "You probably need to install some more Oracle components.\n";
    print "I'll keep going, but the compile will probably fail.\n";
    print "See README.clients for more information.$BELL\n";
    sleep 5;
}

symbol_search() if $::opt_s or $::opt_S;


# --- How shall we link with Oracle? Let me count the ways...

my @mkfiles;
my $linkwith;
my $linkwith_msg;
my $need_ldlp_env;

if ($os eq 'VMS') {
    my $OCIINCLUDE = vmsify("$OH/rdbms/") ." ". vmsify("$OH/rdbms/demo/oci_demo/");
    $opts{INC}  = "$OCIINCLUDE $dbi_arch_dir";
    $opts{OBJECT} = 'oracle.obj dbdimp.obj oci7.obj oci8.obj' if $] < 5.005;
}

elsif (($os eq 'MSWin32') or ($os =~ /cygwin/i)) {
    my $OCIDIR = "";
    find( sub {
	print "Found $_ directory\n" if /^OCI\d*$/i;
	$OCIDIR = $_ if /^OCI\d*$/i && $OCIDIR lt $_;
	$File::Find::prune = 1 if -d $_ && $_ !~ /^\./;
    }, $OH );
    die "OCI directory not found, please install OCI in $OH" if ! $OCIDIR;
    print "Using OCI directory '$OCIDIR'\n";

    if ($Config{cc} =~ /gcc/i) {
      system("dlltool --input-def oci.def --output-lib liboci.a")
	  if ! -f "liboci.a";
      die "Could not find or create liboci.a.  See README.wingcc\n"
	  if ! -f "liboci.a";
      my $pwd = cwd();
      $opts{LIBS} = [ "-L$pwd -loci" ];
    } else {
      my %OCILIB;
      my $oci_compiler_dir;
      my @oci_compiler_dirs =
	  map { -d "$OH/$OCIDIR/lib/$_" ? "$OH/$OCIDIR/lib/$_": () }
	  $Config{cc} eq 'bcc32' ? qw(BORLAND BC) : qw(MSVC);
      find( sub {
	$File::Find::prune = 1 if -d $_ && $_ !~ /^\./;
	return unless /^(OCI|ORA).*\.LIB$/i;
	($oci_compiler_dir = $File::Find::dir) =~ s:^.*/::;
	print "Found $OCIDIR/lib/$oci_compiler_dir/$_ library\n";
	$OCILIB{uc($_)} = $_;
      }, @oci_compiler_dirs );
      # sort the version numbered libs into assending order
      my @OCILIB = sort grep { /(OCI|ORA)\d\d+\./i } keys %OCILIB;
      # prefer the non-versioned library if present
      push @OCILIB, "OCI.LIB"    if $OCILIB{'OCI.LIB'};
      # opt_8 means DISABLE use of OCI 8 API
      push @OCILIB, "OCIW32.LIB" if $OCILIB{'OCIW32.LIB'} && $::opt_8;
      my $OCILIB = pop @OCILIB || '';
      $OCILIB =~ s/\.LIB$//i;
  
      die qq{
      Unable to find required Oracle OCI files for the build.  Please check
      that you have your OCI installed in your oracle home ($OH) 
      directory and that it has the following files (and probably more):
  
	$OH\\$OCIDIR\\include\\oratypes.h
	$OH\\$OCIDIR\\lib\\$oci_compiler_dir\\$OCILIB.lib
  
      Please install OCI or send comments back to dbi-users\@perl.org
      if you have an OCI directory other than $OCIDIR.  
  
      } unless  (-e "$OH/$OCIDIR/include/oratypes.h" 
	      && -e "$OH/$OCIDIR/lib/$oci_compiler_dir/$OCILIB.lib")
	      or $::opt_F;
  
      print "Using $OCIDIR/lib/$oci_compiler_dir/$OCILIB.lib\n";
      $opts{LIBS} = [ "-L$OH/$OCIDIR/LIB/$oci_compiler_dir $OCILIB" ];
    };

    my $OCIINCLUDE = "-I$OH/$OCIDIR/include -I$OH/rdbms/demo";
    $opts{INC}  = "$OCIINCLUDE -I$dbi_arch_dir";
}

# --- UNIX Variants ---

elsif ($::opt_l and # use -l to enable this direct-link approach
	@_=grep { m:/lib(cl(ie)?ntsh|oracle).\w+$:o } <$OH/lib/lib*>
    ) {
    # --- the simple modern way ---
    foreach(@_) { s:\Q$OH/lib/::g }
    print "Found direct-link candidates: @_\n";
    my $lib = ("@_" =~ m:lib(cl(ie)?ntsh)\.:) ? $1 : "oracle";
    $linkwith_msg = "-l$lib.";
    my $syslibs = read_sysliblist();
    print "Oracle sysliblist: $syslibs\n";
    $opts{LIBS} = [ "-L$OH/lib -l$lib $syslibs" ];
    $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g" };
    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
    $opts{INC}  = "$inc -I$dbi_arch_dir";
}
else {	# --- trawl the guts of Oracle's make files looking the how it wants to link

    my @ora_libs = <$OH/lib/lib*>;
    if (@ora_libs < 6) { # just a helpful hint
	warn "\nYou don't seem to have many Oracle libraries installed. If the"
	    ."\nbuild fails you probably need to install more Oracle software.\n\n";
	sleep 6;
    }

    # can we give the shared library a helping hand?
    my @shared = grep { m:/lib(cl(ie)?ntsh|oracle).\w+$:o } @ora_libs;
    # show original value of ORA_CLIENT_LIB if defined ...
    print "\$ORA_CLIENT_LIB=$ENV{ORA_CLIENT_LIB}\n"
		if defined $ENV{ORA_CLIENT_LIB};
    # ... before we then set it how it probably should be set
    # XXX but we still need to write it into the generated Makefile.
    $ENV{ORA_CLIENT_LIB} = 'shared'
		if !defined $ENV{ORA_CLIENT_LIB}
		&& ($opts{LINKTYPE}||'') ne 'static' && @shared && !$::opt_c;

    my $mkfile = find_mkfile();
    my $linkvia = fetch_oci_macros($mkfile) if -f $mkfile;

    my $libhome = expand_mkvars($MK{LIBHOME}, 0, 1) || "$OH/lib";
    $linkwith = expand_mkvars($linkvia, 0, 1);

    if ($mk_target_rules{build} && $::opt_b) {
	print "\n";
	print "Attempting to discover Oracle OCI build rules...\n";
	my $rules = join "\n", '', @{ $mk_target_rules{build} };
	# create dummy C file to keep 'make $mkfile' happy
	my $DBD_ORA_OBJ = 'DBD_ORA_OBJ';
        open DBD_ORA_C, ">$DBD_ORA_OBJ.c"
	    or die "Can't create temporary $DBD_ORA_OBJ.c file in current directory: $!\n";
        print DBD_ORA_C "int main() { return 1; }\n";
        close DBD_ORA_C;
	sleep 2; #
	system("make $DBD_ORA_OBJ.o CC='$Config{cc}'");
	my $make = "$Config{make} -f $mkfile build"
		." ECHODO=echo ECHO=echo GENCLNTSH='echo genclntsh' CC=echo"
		." OPTIMIZE= CCFLAGS="
		." EXE=DBD_ORA_EXE OBJS=$DBD_ORA_OBJ.o";
	print "by executing:\n[$make]\n" if $::opt_v;
	my @cmds = `$make 2>&1`;
	print "returned:\n[".join("\n[",@cmds)."]\n" if $::opt_v;
	warn "Warning: Oracle build rule discovery failed ($?)\n" if $?;

	my @filtered_cmds;
        while (my $line = shift @cmds) {
	    # join lines split with \'s
	    while ($line =~ s/\\$/ /)  { $line .= shift @cmds; }
	    # remove any echo's as the following line should be the result of the echo
	    if ($line =~ /^\s*echo\s+/) {
		$line = shift @cmds; # replace line with the next one
		$line =~ s/^echo\s+//; # handle " echo echo ..." case
	    }
	    next if $line =~ /^\s*$/; # remove any blank lines
	    push @filtered_cmds, $line;
	}
	@cmds = @filtered_cmds;

	print "reduced to:\n[".join("\n[",@cmds)."]\n" if $::opt_v;

	# expand any shell-escapes that remain 
	#@cmds = map { s/`(.*?[^\\])`/expand_shellescape("$1", 1)/esg; $_ } @cmds;

	my @prolog; push @prolog, shift @cmds while @cmds && $cmds[0] !~ /DBD_ORA_EXE/;
	print "Oracle oci build prolog:\n\t+ ",  join("\n\t+ ", @prolog), "\n" if @prolog;
	print "Oracle oci build command:\n\t+ ", join("\n\t+ ", @cmds), "\n";
 	if (@cmds == 2) {
 		# Newer Oracle (>8.0.5, it seems) seem to disregard ECHODO, in
 		# which case the make output probably looked like this:
 		#      echo foo `bar` baz
 		#      foo shell-expanded-bar baz
 		# So let's check for that, and fix things up if so
 		if (my($foo) = ($cmds[0] =~ /^echo\s+([^`]+)`/)) {
 			if ($cmds[1] =~ /^$foo/) {
 				# The second line looks like the expanded
 				# version of the first; let's fix it up like
 				# we're expecting it to look and use it
 				@cmds = ("true echo $cmds[1]");
 			}
 		}
 	}
	if (@cmds == 1) {
	    my $build = $cmds[0];
	    #$build =~ s/^\s*(true\s+)?(\S+)\s*//;	# remove 'true' and compiler/linker
	    $build =~ s/$DBD_ORA_OBJ.o//;		# remove dummy object file
	    $build =~ s/\S+\s+DBD_ORA_EXE//;	# remove dummy exe file and preceding flag
	    $linkwith = $build;
	    # delete problematic crt?.o on solaris
	    $linkwith = del_crtobj($linkwith, 1) if $os eq 'solaris';
	}
	else {
	    print "Unable to interpret Oracle build commands from $mkfile. Using fallback approach.\n";
	    $::opt_b = 0;
	}
	unlink "$DBD_ORA_OBJ.c", "$DBD_ORA_OBJ.o";
	print "\n";
    }
    else {
	print "Warning: Oracle $mkfile doesn't define a 'build' rule.\n" if $::opt_b;
	$::opt_b = 0;
	print "\n";
	print "Warning: I will now try to guess how to build and link DBD::Oracle for you.$BELL\n";
	print "         This kind of guess work is very error prone and Oracle-version sensitive.\n";
	print "         It is possible that it won't be supported in future versions of DBD::Oracle.\n";
	print "         *PLEASE* notify dbi-users abut exactly _why_ you had to build it this way.\n";
	print "\n";
	sleep 6;
    }

    $linkwith =~ s/-Y P,/-YP,/g if $Config{gccversion};
    $linkwith =~ s:-R /:-R/:g if $os eq 'solaris';

    # modifications (mostly) by lbaxter@fleetcc.com
    if ( ($os eq 'hpux') && ($osvers > 10) && ($Config{'cc'} eq 'cc') )
    {
        # these get dragged in from demo_rdbms.mk where Oracle uses them
        # the linker bitches about them not being valid options
        # in this context
        $linkwith =~ s/-Wl,\+[sn]//g;

        # Oracle 8.0.5 drags in these which also cause link errors:
        # this produces a good link with the 32bit version of oracle
        # (64bit version of 8.0.5 fails to link
        # someone else will have to hack that one out)
        $linkwith =~ s/\+D[AS]2\.0[W]* / /g;

        # A number of folks have had to add this library to resolve
        # undefined symbol errors reported at runtime by ld.sl (the 
        # library loader) libqsmashr defines LhrStringInsert()...
        # other libraries may have to be added (Lincoln Baxter <lbaxter@fleetcc.com>)
        # we check for the library's existence first... (8.0.5 does not have it)
        if ( -r "$OH/lib/libqsmashr.sl" ) {
           $linkwith =~ s/$/ -lqsmashr/ if ( $linkwith !~ m/-lqsmshr/ );
        }

        if ( $osvers >= 11 and #Lincoln: removed os check since it *is* done above...  duh
             $inspdver{RDBMS} =~ /^7.3/ and
             $linkwith =~ m/-lcl\b/ && $linkwith =~ m/-l:libcl.a/
	) {  # from h.m.brand@hccnet.nl
            print "Warning: Stripping -lcl from the link flags, because it\n"
                . "         seems to conflict with -l:libcl.a\n" ;
            $linkwith =~ s/\s*-lcl\b//g;
        }

        # Lincoln: Jay Strauss's Oracle 8.1.6 fix... I did this manually
        #          when I still had 8.1.6 to deal with (its in the README):
        #
        # Jay:     8.1.6 gets Unresolved symbols on LhtStrInsert
        #           $linkwith =~ s/$/ -lclntsh/ if ( $linkwith !~ = m/-lclntsh/ );
        #          }
        #          Tim - Not to be disobedient but at this point of the code
        #          $inspdver{RDBMS} = 0, so I can't do Oracle version 8.1.6 logic
        #          So it seems easier to modify if I do it like below rather than above
        #          obviously its your choice
        #
        # Lincoln: I don't see how the code above could work if $inspdver{RDMS} == 0
        #          so I will add this Jays prefered way but inside a test like that
        #          above... if he tests this and it works great... if someone else is
        #          has a problem it is easy to comment out the test. I like Jay's test
        #          for existence first... And I added an addition test of $OH to see
        #          if it looks like 8.1.6 (just incase Jay was right).
        #
        # Jay:     Add Librarys where one gets Unresolved symbols
        #
        if ( ( $osvers >= 11 and $inspdver{RDBMS} =~ /^8.1.6/ )
        or   ( $osvers >= 11 and $OH =~ m,/8.1.6, ) ) {
            my @extraLib = qw[libqsmashr.sl libclntsh.sl];
            foreach my $extraLib (@extraLib) {
                if (-r "$OH/lib/$extraLib") {
                        $extraLib =~ s/^lib([^\.]+).*$/\-l$1/;
                        $linkwith =~ s/$/ $extraLib/ if ( $linkwith !~ m/$extraLib/ );
                }
            }
        }

         if ( $os eq "hpux" && $osvers >= 11 and $linkwith =~ m/-l:libcl.a/) {
                print "Warning: stripping -l:libcl.a from liblist (conflict with ld looking for shared libs)";
                $linkwith =~ s/\s*-l:libcl.a\b//g;
	}

        if (($linkwith !~ m/-lcl/) || ($linkwith !~ m/-lpthread/)) {
            print "Warning: Oracle is built with multi-threading libraries\n"
                . "         You will most likely need to rebuild perl from sources\n"
                . "         with the following libraries: -lcl -lpthread\n" ;
        }

        if ( ($Config{'cc'} eq 'cc') && ($Config{'ccflags'} !~ m/\+z/ && $Config{'ccldflags'} !~ m/\+Z/i) ) {
            print "Warning: perl was not built with +z in ccflags\n"
                . "         You may need to rebuild perl from sources\n"
                . "         See instructions in README.hpux\n" ;
        }
    }


    if ($::opt_b) {	# The simple approach
	$opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g $linkwith" };
	$linkwith_msg = "OTHERLDFLAGS = $linkwith [from 'build' rule]";
    }
    else {		# the not-so-simple approach!
	# get a cut down $linkwith to pass to MakeMaker liblist
	my $linkwith_s = expand_mkvars($linkwith, 1, 1);

	# convert "/full/path/libFOO.a" into "-L/full/path -lFOO"
	# to cater for lack of smarts in MakeMaker / Liblist
	# which ignores /foo/bar.a entries!
	my $lib_ext_re = "(a|$Config{dlext}|$Config{so})";
	$linkwith_s =~ s!(\S+)/lib(\w+)\.($lib_ext_re)\b!-L$1 -l$2!g;

	# Platform specific fix-ups:
	# delete problematic crt?.o on solaris
	$linkwith_s = del_crtobj($linkwith_s) if $os eq 'solaris';
	$linkwith_s =~ s/-l:lib(\w+)\.sl\b/-l$1/g;	# for hp-ux
	# this kind of stuff should be in a ./hints/* file:
	$linkwith_s .= " -lc" if $Config{osname} eq 'dynixptx'
			      or $Config{archname} =~ /-pc-sco3\.2v5/;
	if ($os eq 'solaris' and $linkwith_s =~ /-lthread/
		and $osvers >= 2.3 and $osvers <= 2.6
	) {
	    print "Warning: Solaris 2.5 bug #1224467 may cause '_rmutex_unlock' error.\n";
	    print "Deleting -lthread from link list as a possible workround ($osvers).\n";
	    $linkwith_s =~ s/\s*-lthread\b/ /g;
	}

	# extract object files, keep for use later
	my @linkwith_o;
	push @linkwith_o, $1 while $linkwith_s =~ s/(\S+\.[oa])\b//;
	# also extract AIX .exp files since they confuse MakeMaker
	push @linkwith_o, $1 while $linkwith_s =~ s/(-bI:\S+\.exp)\b//;

	$linkwith_msg = "@linkwith_o $linkwith_s [from $linkvia]";
	$opts{LIBS} = [ "-L$libhome $linkwith_s" ];
	$opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g @linkwith_o \$(COMPOBJS)" };
    }

    my $OCIINCLUDE = expand_mkvars($MK{INCLUDE} || '', 0, 0);
    $OCIINCLUDE .= " -I$OH/rdbms/demo";
    my $inc = join " ", map { "-I$OH/$_" } @h_dirs;
    $opts{INC}  = "$OCIINCLUDE $inc -I$dbi_arch_dir";
}


# --- Handle special cases ---

if ($::opt_g && $os eq "MSWin32" && $Config::Config{cc} eq "cl") {
   $opts{LDDLFLAGS} = $Config::Config{lddlflags} . ' -debug'
}

$opts{DEFINE} .= ' -Wall -Wno-comment' if $Config{gccversion} eq 'gcc';

$opts{DEFINE} .= ' -Xa' if $Config{cc} eq 'clcc';	# CenterLine CC

$opts{DEFINE} .= ' -DNO_OCI8' if $::opt_8;

$opts{DEFINE} .= ' -DUTF8_SUPPORT' if ($] >= 5.006);

# Set some private WriteMakefile options if this is 'me' :-)
if ($is_me){  # a reasonable guess
    $BELL = "<BELL>";
    # -Wconversion is over-noisy for us
    $opts{DEFINE} .= ' -Wall -Wcast-align -Wpointer-arith'
	. ' -Wbad-function-cast -Wcast-qual' if $Config{gccversion};
    $::opt_g = '-g';
    $opts{dynamic_lib}->{OTHERLDFLAGS} = "$::opt_g ".($opts{dynamic_lib}->{OTHERLDFLAGS}||'');
}

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($os eq 'hpux') {
    print "***$BELL\n";
    $osvers =~ s/^[a-z]\.//;	# Sigh... 'b.11.0' etc
    if ($osvers < 10) {
	print "*** Warning: Forced to build static not dynamic on $os $osvers.$BELL\n";
	$opts{LINKTYPE} = 'static';
    }
    else {
	print "*** Warning: If you have trouble, see README.hpux...\n"
	     ."    you may have to build your own perl, or go hunting for libraries\n";
    }
    print "***$BELL\n";
    sleep 3;
    $opts{DEFINE} .= ' $(HP64DEFINES)'
        if ($Config{archname} =~ /-thread\b/i and $Config{ccflags} =~ /\+DD64\b/);
    # see also const_cccmd for -Aa to -Ae flag change
}


# --- check for Test::Harness bug 

eval { package WAIT; require 'wait.ph' };
if (!$@ && !defined(&WAIT::WCOREDUMP)) { 
    print "\n";
    print "You have a wait.ph file generated by perl h2ph utility.\n";
    print "It does not define a WCOREDUMP function. That's probably an error.\n";
    print "If a DBD::Oracle test fails then you will probably see a message\n";
    print "from Test::Harness about WCOREDUMP being undefined. You can either ignore\n";
    print "it or try to fix your wait.ph file. The message does not reflect the\n";
    print "cause of the test failure, it's just a problem interpreting the failure.\n";
    print "\n";
} 


# --- display summary information

# log key platform information to help others help you quickly if needed
print "\n";
print "System: perl$] @Config{qw(myuname)}\n";
print "Compiler:   @Config{qw(cc optimize ccflags)}\n";
print "Linker:     ". (find_bin('ld')||"not found") ."\n" unless $os eq 'VMS';
print "Sysliblist: ".read_sysliblist()."\n";
print "Oracle makefiles would have used these definitions but we override them:\n"
	if $MK{CFLAGS} || $MK{LDFLAGS} || $MK{LDSTRING};
print "  CC:       $MK{CC}\n\n"	if $MK{CC};
print "  CFLAGS:   $MK{CFLAGS}\n"                    if $MK{CFLAGS};
print "           [".mkvar('CFLAGS',0,1,0).  "]\n\n" if $MK{CFLAGS};
print "  CLIBS:    $MK{CLIBS}\n"                     if $MK{CLIBS};
print "           [".mkvar('CLIBS',0,1,0).   "]\n\n" if $MK{CLIBS};
if ($mk_target_rules{build} && !$::opt_b) {
    my $rules = join "\n", '', @{ $mk_target_rules{build} };
    $rules = expand_mkvars($rules, 0, 0, 1, 1) if $rules =~ /^\s*\$\(\w+\)\s*$/;
print "  build:    $rules\n";
print "           [".expand_mkvars($rules,0,1,0).   "]\n\n";
}
print "  LDFLAGS:  $MK{LDFLAGS}\n"                   if $MK{LDFLAGS};
print "           [".mkvar('LDFLAGS',0,1,0). "]\n\n" if $MK{LDFLAGS};
print "  LDSTRING: $MK{LDSTRING}\n"                  if $MK{LDSTRING};
print "           [".mkvar('LDSTRING',0,1,0)."]\n\n" if $MK{LDSTRING};
print "\nLinking with $linkwith_msg\n" if $linkwith_msg;
print "\n";

# --- display extra notes and warnings

if ($os eq 'aix' and $osvers >= 4 and $Config{cc} ne 'xlc_r') {
    print "\n\n";
    print "Warning: You will probably need to rebuild perl using the xlc_r compiler.$BELL\n";
    print "         You may also need do: ORACCENV='cc=xlc_r'; export ORACCENV\n";
    print "         Also see the README about the -p option\n";
    sleep 5;
}

if ($inspdver{rdbms_ver} >= 8.106 && $Config{archname} !~ /-thread\b/i) {
    print "\n";
    print "Warning: If you have problems you may need to rebuild perl with threading enabled.$BELL\n";
    sleep 5;
}

if ($Config{usemymalloc} eq 'y') {
    print "\n";
    print "Warning: If you have problems you may need to rebuild perl with -Uusemymalloc.$BELL\n";
    sleep 5;
}

print "Warning: Your GNU C compiler is very old. Please upgrade.\n"
    if ($Config{gccversion} and $Config{gccversion} =~ m/^(1|2\.[1-5])/);

if ($opts{LINKTYPE} && $opts{LINKTYPE} eq 'static') {
    print "** Note: DBD::Oracle will be built *into* a NEW perl binary. You MUST use that new perl.\n";
    print "         See README and Makefile.PL for more information.$BELL\n";
}


# --- write the name file etc ---

# create this before WriteMakefile so MakeMaker knows it's here
open(MK_PM, ">mk.pm") or die "Unable to create mk.pm: $!";

print "\n";
WriteMakefile( dbd_edit_mm_attribs(\%opts) );

check_security() unless $os eq 'VMS' or $os eq 'MSWin32' or $os =~ /cygwin/i;

print "\n";
print "***  If you have problems...\n";
print "     read all the log printed above, and the README and README.help files.\n";
print "     (Of course, you have read README by now anyway, haven't you?)\n\n";

exit 0;


# =====================================================================


sub win32_oracle_home {
  my $oh = shift;

  my ($req_ok, $hkey, $Val, $Keys);
  my $default_home;
  if ( ! $oh ) {
      if ( $Config{osname} eq "MSWin32") {
	  # Win32::TieRegistry is prefered, but it requires Win32API::Registry
	  # which is not available in mingw or cygwin
	  eval {
	      require Win32::TieRegistry;
	      $Win32::TieRegistry::Registry->Delimiter("/");
	      $req_ok = 1;
	      $hkey = $Win32::TieRegistry::Registry->{"LMachine/SOFTWARE/Oracle/"};
	  };
	  eval { # older name of Win32::TieRegistry
	      require Tie::Registry;
	      $Tie::Registry::Registry->Delimiter("/");
	      $req_ok = 1;
	      $hkey = $Tie::Registry::Registry->{"LMachine/SOFTWARE/Oracle/"};
	  } unless $req_ok;
	  eval {
	     $default_home = $hkey->{ORACLE_HOME} || '';
	  };
	  eval {
	      $Val = sub {
		  # Return value
		  my ($hkey) = @_;
		  return $hkey->{ORACLE_HOME} || '';
	      };
	      $Keys = sub {
		  # Return list of sub-folder keys
		  my ($hkey) = @_;
		  # MAC: %$hkey and related method calls don't work under
		  #      perl5db, so don't try single stepping through here
		  return map {m:/$: ? $hkey->{$_} : ()} keys %$hkey;
	      };
	  } if $hkey;
      }

      # Win32::Registry imports some symbols into main::
      # this is not commonly wanted, so try this as a last resort
      # MAC: it is available under mingw and might be available under cygwin
      #      If cygwin doesn't have it, move the rest inside the other if block
      eval {
	  require Win32::Registry;
	  $main::HKEY_LOCAL_MACHINE->Open('SOFTWARE\\ORACLE', $hkey);
	  my $dummy = $main::HKEY_LOCAL_MACHINE; # avoid single use complaint
	  eval {
	     my $hval;
	     $hkey->GetValues($hval);
	     $default_home = $hval->{ORACLE_HOME}[2] || '';
	  };
	  $Val = sub {
	      # Return value
	      my ($hkey) = @_;
	      my $hval;
	      $hkey->GetValues($hval);
	      return $hval->{ORACLE_HOME}[2] || '';
	  };
	  $Keys = sub {
	      # Return list of sub-folder keys
	      my ($hkey) = @_;
	      my @hkey;
	      $hkey->GetKeys(\@hkey);
	      @hkey = map { $hkey->Open($_, $_); $_ } @hkey;
	      return @hkey;
	  };
      } unless $req_ok;

      # Workaround Win32::TieRegistry FETCH error during global destruction.
      undef $Win32::TieRegistry::Registry if $Win32::TieRegistry::Registry;

      # Look for ORACLE_HOME in all ORACLE sub-folders, use last one found
      #     before 8.1.5, there should be only one
      eval {
	  my ($oh1, %oh);
	  my @hkey = ($hkey);
	  # JLU: December 5, 2002: if the "default" home is set and has
	  # an OCI directory, then use it.
	  if ($default_home && -d $default_home && -d $default_home . "/oci") {
	     $oh = $default_home;
	  } else {
	     # use previous logic if default home doesn't have OCI
	     # directory
	     while (@hkey) {
		$hkey = shift @hkey;
	      $oh   = $oh1, $oh{$oh1} = 1
		  if ($oh1 = &$Val($hkey)) && -d $oh1;
	      push @hkey, &$Keys($hkey);
	     }
	     if (1 < keys %oh) {
	        # JLU: 8/21/01 Oracle's default home is the first one in
	        # the path, at least with 8i
		print "\n\007Multiple Oracle homes: ", join(" ", sort keys %oh), "\n\n";
		my @path = split(";", $ENV{PATH});
		my $dir;
		foreach $dir (@path) {
	           # the path will be c:\path\to\home\bin, so remove \bin if it's there.
		   $dir =~ s/\\bin$//;
		   if (defined($oh{$dir})) {
		      print "$dir is first in the PATH, so we'll use that as Oracle's default home.\n\n";
		      $oh = $dir;
		      last;
		   }
		}
	     }
	  }
      } if defined $Keys;
  }

  $oh =~ s:\\:/:g if $oh;
  return $oh
}


sub read_sysliblist {
    my $syslibs = (-f "$OH/lib/sysliblist")
	? read_file("$OH/lib/sysliblist")
	: (-f "$OH/rdbms/lib/sysliblist") ? read_file("$OH/rdbms/lib/sysliblist") : '';
    #$syslibs =~ s/-l:lib(\w+).(sl|a)\b/-l$1/g if $os eq 'hpux';
    if ($os eq "hpux") {
       $syslibs =~ s/-l:lib(\w+).(sl|a)\b/-l$1/g;
       $linkwith =~ m/-lcl\b/ or
           $syslibs =~ s/\s*-lcl\b//g;
    }
    return $syslibs;
}


# =====================================================================



sub del_crtobj {
    my $orig = shift;
    my $verbose = shift || $::opt_v;
    my $str = $orig;
    # E.g. for changing the COMPOBJS line (and sometimes LDSTRING)
    # old: COMPOBJS=$(COMPOBJ)/crti.o $(COMPOBJ)/crt1.o $(COMPOBJ)/__fstd.o
    # new: COMPOBJS=$(COMPOBJ)/__fstd.o
    my @del;
    push @del, $1 while $str =~ s:([^\s=]*\bcrt[1in]\.o)\b::;
    if ($orig ne $str) {
	print "Deleted @del from link args.\n" if $verbose;
	print "del_crtobj: $orig\n          : $str\n@del\n" if $::opt_v;
    }
    return $str;
}


sub find_mkfile {

    my @mkfiles;
    my @mk_proc = (
	'precomp/demo/proc/proc.mk',
	'precomp/demo/proc/demo_proc.mk',
	'proc/lib/proc.mk',
	'proc16/lib/proc16.mk',
    );
    my @mk_oci = (
	'rdbms/lib/oracle.mk',
	'rdbms/demo/oracle.mk',
	'rdbms/demo/demo_rdbms.mk',
	'otrace/demo/atmoci.mk',
    );
    my @mkplaces = ($::opt_p) ? (@mk_proc,@mk_oci) : (@mk_oci,@mk_proc);
    if ($::opt_m) {
	$::opt_m = cwd()."/$::opt_m" unless $::opt_m =~ m:^/:;
	die "-m $::opt_m: not found" unless -f $::opt_m;
	unshift @mkplaces, $::opt_m;
    }
    my ($mkfile, $place);
    foreach $place (@mkplaces) {
	$place = "$OH/$place"
	    unless $place =~ m:^[/\.]:; # abs or relative path
	next unless -f $place;
	push @mkfiles, $place;
	print "Found $place\n";
    }
    $mkfile = $mkfiles[0];	# use first one found
    die qq{
	Unable to locate an oracle.mk, proc.mk or other suitable *.mk
	file in your Oracle installation.  (I looked in
	@mkplaces)

	The oracle.mk (or demo_rdbms.mk) file is part of the Oracle
	RDBMS product. The proc.mk (or demo_proc.mk) file is part of
	the Oracle Pro*C product.  You need to build DBD::Oracle on a
	system which has one of these Oracle components installed.
	(Other *.mk files such as the env_*.mk files will not work.)

	In the unlikely event that a suitable *.mk file is installed
	somewhere non-standard you can specify where it is using the -m option:
		perl Makefile.PL -m /path/to/your.mk

	See README.clients for more information and some alternatives.

    } unless ($os eq 'MSWin32') || ($os eq 'VMS') || ($mkfile && -f $mkfile) || $::opt_F;

    print "Using $mkfile\n";

    warn "Note: Attempting to use makefile from otrace component. This may not work.\n"
	if ($mkfile =~ /atmoci.mk/);

    return $mkfile;
}


sub fetch_oci_macros {
    my $file = shift;

    # Read $file makefile, extract macro definitions from it
    # and store them in $MK, @MK and %MK.

    # Don't include the following definitions in the generated
    # makefile (note that %MK stills gets these values).
    my @edit = qw(
	SHELL CC CPP CFLAGS CCFLAGS OPTIMIZE ASFLAGS RCC LD LDFLAGS
	AR AS CHMOD ECHO EXE OBJS PERL OBJ_EXT LIB_EXT VERSION
    );
    my %edit; @edit{@edit} = ('$_ = ""') x @edit;

    $edit{ORA_NLS} = $edit{ORA_NLS33} = $edit{ORA_NLS32} = q{
	print "Deleting $_\n",
	    "  because it is not already set in the environment\n",
	    "  and it can cause ORA-01019 errors.\n";
	$_ = '';
    } unless $ENV{ORA_NLS} || $ENV{ORA_NLS33} || $ENV{ORA_NLS32};

    $edit{COMPOBJS} = q{
	# Firstly a Solaris specific edit:
	$_ = del_crtobj($_) if $os eq 'solaris';
	
	# Delete any object files in COMPOBJS that don't actually exist
	my $of;
	foreach $of (split(/=|\s+/)) {
	    next if !$of or $of eq "COMPOBJS";
	    my $obj = expand_mkvars($of,0,0);
	    next if -e $obj;
	    print "Deleting $of from COMPOBJS because $obj doesn't exist.\n";
	    s:\Q$of::;
	} 
    };

    # deal with (some subversions) of Oracle8.0.3's incompatible use of OBJ_EXT
    my $incompat_ext = ($MK{OBJ_EXT} && $MK{OBJ_EXT} !~ /^\./);
    warn "OBJ_EXT correction enabled ($MK{OBJ_EXT})\n" if $incompat_ext;

    my $mkver = 0;
    my $lastline = '';
    my @lines = read_inc_file($file);
    for(1; $_ = shift(@lines); $lastline = $_){
	# Join split lines but retain backwack and newlines:
	$_ .= shift @lines while(m/\\[\r\n]+$/);
	chomp;
	push @MK, '' if $_ eq '' and $lastline ne ''; # squeeze multiple blank lines
	next unless $_;

	if ($incompat_ext) {
	    s/\.(\$\(OBJ_EXT\))/$1/g;
	    s/\.(\$\(LIB_EXT\))/$1/g;
	}

        if (m!^([-\w/+.\$()\s]+)\s*:+\s*([^=]*)!) {     # skip targets
            my @tgts = split(/ /, $1);  # multiple target names in Oracle9i's demo_rdbms.mk
	    for (@tgts) { $mk_target_deps{$_} = $2 || '' }
	    my @rules;
            while (@lines && $lines[0] =~ m!^\t! && chomp $lines[0]) {
                my $tmp_line = shift @lines;
                while($tmp_line =~ m!\\$!) {	# continuations!
                    $tmp_line =~ s/\s+\\$/ /;
                    $tmp_line .= shift @lines;
                    chomp($tmp_line);
                }
		push @rules, $tmp_line;
		#print "target @tgts => $mk_target_deps{$tgt} => @{$mk_target_rules{$tgt}}\n";
            }  
	    for (@tgts) { push @{ $mk_target_rules{$_} ||= [] }, @rules }
            next;
        }

	next if m!^\t!;					# skip target build rules
	next if m/^\s*\.SUFFIXES/;

	unless($MK{mkver}) {	# still want to get version number
	    my $line = $_; $line =~ s/[\\\r\n]/ /g;
	    $MK{mkver} = $mkver = $1
		if $line =~ m/\$Header:.*?\.mk.+(\d+\.\d+)/;
	}

	# We always store values into %MK before checking %edit
	# %edit can edit this in addition to $_ if needed.
	my $name;
	if (m/^\s*(\w+)\s*(\+?)=\s*/) {
	    $name = $1;
	    my $append = $2;
	    my $value  = $';
	    $value =~ s/^\@`/`/;
	    if ($append) {
		my $expanded = expand_mkvars($value, 0, 1);
		print "Appending '$expanded' to $name\n";# if $verbose;
		$value = $MK{$name} ? "$MK{$name} $expanded" : $expanded;
	    }
	    elsif ($MK{$name} && $MK{$name} ne $value) {
		print "$name macro redefined by Oracle\n from $MK{$name}\n   to $value\n"
			if $::opt_v;
	    }
	    $MK{$name} = $value;
	    $MK{$name} =~ s/^([^#]*)#.*/$1/; # remove comments

	    if (exists $edit{$name}) {
		my $pre = $_;
		eval $edit{$name};	# execute code to edit $_
		print "Edit $name ($edit{$name}) failed: $@\n" if $@;
		if ($_ ne $pre and $::opt_v) {
		    $_ ? print "Edited $name definition\n from: $pre\n   to: $_\n"
		       : print "Deleted $name definition: $pre\n";
		}
	    }
	}

	push(@MK, $_);
    }

    # --- now decide what to link with ---
    my $linkvia;

    if ($::opt_n) {
	$linkvia = "\$($::opt_n)" if $MK{$::opt_n};
	warn "Can't use '$::opt_n': not defined by .mk files\n"
		unless $linkvia;
    }

    # modern Oracle .mk files define OCISTATICLIBS and OCISHAREDLIBS
    if (!$linkvia && ($MK{OCISHAREDLIBS} || $MK{OCISTATICLIBS})) {
	$linkvia = '';
	if ($MK{OCISTATICLIBS} &&
		(  ($opts{LINKTYPE}||'') eq 'static'
		|| "@ARGV" =~ m/\bLINKTYPE=static\b/
		|| $::opt_c)
    ) {
	    $linkvia .= '$(DEF_ON) '   if $MK{DEF_ON};
	    $linkvia .= '$(SSCOREED) ' if $MK{SSCOREED};
	    $linkvia .= '$(OCISTATICLIBS)';
	}
	else {
	    $linkvia .= '$(SSDBED) '	if $MK{SSDBED};
	    $linkvia .= '$(DEF_OPT) '	if $MK{DEF_OPT};
	    if ($inspdver{RDBMS} =~ /^8\.0\./ and $os eq 'dec_osf' and $osvers >= 4.0) {
		$linkvia .= '$(SCOREPT) $(NAETAB) $(NAEDHS) $(LLIBRDBMS_CLT) $(LLIBMM) ';
		$linkvia .= '$(NETLIBS) $(CORELIBS) $(LLIBCOMMON) $(LLIBEPC) ';
		$need_ldlp_env = "LD_LIBRARY_PATH";
	    }
	    $linkvia .= '$(OCISHAREDLIBS)';
	}
    }

    $linkvia = '$(LIBCLNTSH)' if !$linkvia && $MK{LIBCLNTSH};

    # The oracle.mk file tends to define OCILDLIBS
    $linkvia = '$(OCILDLIBS)' if !$linkvia && $MK{OCILDLIBS};

    # Now we get into strange land of twisty turny macros
    if (!$linkvia && $MK{PROLDLIBS}) {	# Oracle 7.3.x
	# XXX tweak for threaded perl? - use PROLLSsharedthread
	if ($MK{PROLDLIBS} =~ /thread/i && $MK{PROLLSshared}) {
	    $linkvia = '$(PROLLSshared)';
	}
	else {
	    $linkvia = '$(PROLDLIBS)';
	}
    }
    elsif (!$linkvia && int($mkver) == 1) {
	if ($MK{LLIBOCIC}) {
	    $linkvia = '$(LLIBOCIC) $(TTLIBS)';
	} else {
	    print "Warning: Guessing what to link with.\n";
	    $linkvia = '-locic $(TTLIBS)';	# XXX GUESS HACK
	}
    }
    unless ($linkvia){
	die "ERROR parsing $file: Unable to determine what to link with.\n"
	."Please send me copies of these files (one per mail message):\n@mkfiles\n";
    }
    $MK_TEXT = join("\n", @MK);
    return $linkvia;
}


sub read_inc_file {
    my $file = shift;
    my $fh;
    unless ($fh = new FileHandle "<$file") {
	# Workaround more oracle bungling (Oracle 7.3.2/Solaris x86)
	my $alt; ($alt = $file) =~ s/\.dk\.mk$/\.mk/;
	$fh = new FileHandle "<$alt";
	die "Unable to read $file: $!" unless $fh;
    }
    print "Reading $file.\n";
    my @lines;
    push(@mkfiles, $file);
    while(<$fh>) {
	# soak up while looking for include directives
	push(@lines, $_), next
	    unless /^\s*include\s+(.*?)\s*$/m;
	my $inc_file = $1;
	# deal with "include $(ORACLE_HOME)/..."
	# (can't use expand_mkvars() here)
	$inc_file =~ s/\$\((ORACLE_HOME|ORACLE_ROOT)\)/$ENV{$ORACLE_ENV}/og;
	push(@lines, read_inc_file($inc_file));
    }
    print "Read a total of ".@lines." lines from $file (including inclusions)\n" if $::opt_v;
    return @lines;
}


my %expand_shellescape;
sub expand_shellescape { 
    my($orig, $level) = @_;
    my $cmd = $orig;
	my $debug = $::opt_d || 1;
    print "Evaluating `$orig`\n"
		if $debug && !$expand_shellescape{$orig};
    # ensure we have no $(...) vars left - strip out undefined ones:
    $cmd =~ s/\$[({](\w+)[})]/mkvar("$1", 1, 0, $level+1)/ge;
    print "  expanded `$cmd`\n" if $debug and $cmd ne $orig;
    my $result = `$cmd`;
    $result =~ s/\s+$/ /; # newlines etc to single space
    print "  returned '$result'\n"
		if $debug && !$expand_shellescape{$orig};
	$expand_shellescape{$orig} = $result;
    $result;
}

sub expand_mkvars { 
    my ($string, $strip, $backtick, $level, $maxlevel) = @_;
    $level ||= 1;
    local($_) = $string;
    print "$level Expanding $_\n" if $::opt_d;
    # handle whizzo AIX make feature used by Oracle
    s/\$[({] (\w+) \? ([^(]*?) : ([^(]*?) [})]/
	my ($vname, $vT, $vF) = ($1,$2,$3);
	$MK{$vname} = (mkvar($vname, 1, $backtick, $level+1)) ? $vT : $vF
    /xge; # can recurse
    s/\$[({] (\w+) [})]/
	mkvar("$1", $strip, $backtick, $level+1, $maxlevel)
    /xge; # can recurse
    s/`(.*?[^\\])`/expand_shellescape("$1", $level+1)/esg if $backtick; # can recurse
    s/\s*\\\n\s*/ /g;	# merge continuations
    s/\s+/ /g;	# shrink whitespace
    print "$level Expanded $string\n  to       $_\n\n" if $::opt_d and $_ ne $string;
    $_;
}


sub mkvar { 
    my($var, $strip, $backtick, $level, $maxlevel) = @_;
    my  $default = $strip ? '' : "\$($var)";
    print "$level Variable: $var\n" if $::opt_d;
    return '$(LIBHOME)' if $var eq 'LIBHOME' && !$strip; # gets noisy
    return $ENV{$ORACLE_ENV} if $var eq 'ORACLE_HOME';
    my $val = $MK{$var};
    if (!defined $val and exists $ENV{$var}) {
	$val = $ENV{$var};
	print "Using value of $var from environment: $val\n"
		unless $var eq 'LD_LIBRARY_PATH';
    }
    return $default unless defined $val;
    if ($MK_expanding{$var}) {
	print "Definition of \$($var) includes \$($var).\n";
	return "\$($var)";
    }
    local($MK_expanding{$var}) = 1;
    return $val if $maxlevel && $level >= $maxlevel;
    return expand_mkvars($val, $strip, $backtick, $level+1, $maxlevel); # can recurse
}


sub read_file {
    my $file = shift;
    unless (open(ROL, "<$file")) {
	warn "WARNING: Unable to open $file: $!\n";
	return "";
    }
    my $text = join "", <ROL>;
    $text =~ s/\n+/ /g;
    close ROL;
    return $text;
}


sub find_bin{
    my $bin = shift;
    my $path_sep = $Config{path_sep};
    foreach (split(/$path_sep/, $ENV{PATH})){
	return "$_/$bin" if -x "$_/$bin";
    }
    return "<$bin not found>";
}


sub find_headers {
    my (%h_dir, @h_dir);
    find( sub {
	return unless /^o(ci.{3,4}|ratypes)\.h$/i;
	my $dir = $File::Find::dir;
	$dir =~ s:^\Q$OH/::;
	$h_dir{$dir} = $_;
	print "Found $dir/$_\n" if $::opt_v;
    }, "$OH/rdbms" );
    @h_dir = keys %h_dir;
    print "Found header files in @h_dir.\n" if @h_dir;
    return @h_dir;
}


sub symbol_search {
    $::opt_s ||= $::opt_S;
    print "Searching for symbol '$::opt_s' in $OH ...\n";
    my $dlext = $Config{dlext};
    system(qq{	cd $OH; for i in lib/*.[ao] lib/*.$dlext */lib/*.[ao];
	do echo "  searching oracle \$i ..."; PATH=/usr/ccs/bin:\$PATH nm \$i | grep $::opt_s; done
    });
    if ($::opt_S) {
	my @libpth = split ' ', $Config{libpth};
	print "Searching for symbol '$::opt_s' in @libpth ...\n";
	@libpth = map { ("$_/lib*.$dlext", "$_/lib*.a") } @libpth;
	system(qq{	cd $OH; for i in @libpth;
	    do echo "  searching \$i ..."; PATH=/usr/ccs/bin:\$PATH nm \$i | grep $::opt_s; done
	});
    }
    print "Search done.\n";
    print "(Please only include the 'interesting' parts when mailing.)\n";
    exit;
}


# =====================================================================


{
    package MY; # SUPER needs package context, $self is not sufficient

    use strict;
    use Config;


    sub post_initialize {
	my $self = shift;

	if (-f "$Config{installprivlib}/DBD/Oraperl.pm"){ # very old now
	    print "
Please note: the Oraperl.pm installation location has changed.
It was: $Config{installprivlib}/DBD/Oraperl.pm
Is now: $Config{installprivlib}/Oraperl.pm
You have an old copy which you should delete when installing this one.\n";
	}

	print "\nNote: \$ORACLE_HOME/lib must be added to your $need_ldlp_env environment variable\n",
	      "before running \"make test\" and whenever DBD::Oracle is used.\n\n"
	    if $need_ldlp_env && ($ENV{$need_ldlp_env}||'') !~ m:\Q$OH/lib\b:;

	# Ensure Oraperl.pm and oraperl.ph are installed into top lib dir
	$self->{PM}->{'Oraperl.pm'} = '$(INST_LIB)/Oraperl.pm';
	$self->{PM}->{'oraperl.ph'} = '$(INST_LIB)/oraperl.ph';

	eval {	# This chunk is for Oracle::OCI
	    require Data::Dumper;
	    print main::MK_PM Data::Dumper->Purity(1)->Terse(0)->Indent(1)->Useqq(1)
		->Dump([\%opts, $self], [qw(dbd_oracle_mm_opts dbd_oracle_mm_self)]);
	};
	if ($@) {
	    warn "Can't dump config to mk.pm so you won't be able to build Oracle::OCI later if you wanted to: $@\n";
	    print main::MK_PM qq{die "You need to reinstall DBD::Oracle after installing Data::Dumper\n"; };
	}
	close main::MK_PM or die "Error closing mk.pm: $!\n";

	foreach (qw(mk.pm Oracle.h dbdimp.h ocitrace.h)) {
	    $self->{PM}->{$_} = '$(INST_ARCHAUTODIR)/'.$_;
	}

	# Add $linkwith to EXTRALIBS for those doing static linking
	$self->{EXTRALIBS} .= " -L\$(LIBHOME)";
	$self->{EXTRALIBS} .= " $linkwith" if $linkwith;

	'';
    }


    sub postamble {
	return main::dbd_postamble(@_);
    }


    sub const_loadlibs {
	my $self = shift;
	local($_) = $self->SUPER::const_loadlibs(@_);
	# edit LD_RUN_PATH ...
	my ($ldrp) = m/^LD_RUN_PATH\s*=\s*(.*)/m;
	# remove redundant /lib or /usr/lib as it can cause problems
	$ldrp =~ s!:(/usr)?/lib$!!;
	# if it's empty then set it manually
	$ldrp ||= "$OH/lib:$OH/rdbms/lib";
	# stitch it back in
	s/^LD_RUN_PATH\s*=\s*(.*)/LD_RUN_PATH=$ldrp/m;
	my $env = $ENV{LD_RUN_PATH};
	print "Ignoring LD_RUN_PATH='$env' in environment\n" if $env;
	print "LD_RUN_PATH=$ldrp\n";
	return $_;
    }


    sub post_constants {
	my $self = shift;
	return '' unless $::opt_f;
	# Oracle Definitions, based on $(ORACLE_HOME)/proc/lib/proc.mk
	'
###################################################################
#
ORACLE_HOME = '.$OH.'

# The following text has been extracted from '.join("\n#\t", '', @mkfiles).'

'.$MK_TEXT.'

# End of extract from '."@mkfiles".'
#
###################################################################
';
    }


    sub const_cccmd {
	my ($self) = shift;
	print "Using DBD::Oracle $self->{VERSION}.\n";

	local($_) = $self->SUPER::const_cccmd(@_);
	# If perl Makefile.PL *-g* then switch on debugging
	if ($::opt_g) {
	   if ($os eq "MSWin32" and $Config::Config{cc} eq 'cl') {
	      s/\s-/ -Zi -/;
	      s/-O1//;
	   } else {
	    s/\s-O\d?\b//;	# delete optimise option
	    s/\s-/ -g -/;	# add -g option
	   }
	}
	# are we using the non-bundled hpux compiler?
	if ($os eq "hpux" and $Config::Config{ccflags} =~ /-Aa\b/) {
	    print "Changing -Aa to -Ae for HP-UX in ccmd.\n"
	     if s/-Aa\b/-Ae/g;	# allow "long long" in oratypes.h
	}

	$_;
    }

    sub cflags {
	my ($self) = shift;
	local($_) = $self->SUPER::cflags(@_);
	# If perl Makefile.PL *-g* then switch on debugging
	if ($::opt_g) {
	   if ($os eq "MSWin32" and $Config::Config{cc} eq 'cl') {
	      s/\s-/ -Zi -/;
	      s/-O1//;
	      
	   } else {
	      s/\s-O\d?\b//;	# delete optimise option
  	      s/\s-/ -g -/;	# add -g option
	   }
	}
	# are we using the non-bundled hpux compiler?
	if ($os eq "hpux" and $Config::Config{ccflags} =~ /-Aa\b/) {
	    print "Changing -Aa to -Ae for HP-UX in cflags.\n"
	     if s/-Aa\b/-Ae/g;	# allow "long long" in oratypes.h
	}
	$_;
    }

    sub dynamic_lib {
	return shift->SUPER::dynamic_lib(@_) unless $os eq 'VMS';

	# special code for VMS only
	my($self, %attribs) = @_;
	return '' unless $self->needs_linking(); #might be because of a subdir
	return '' unless $self->has_link_code();

	my $OtherText;
	my($otherldflags) = $attribs{OTHERLDFLAGS} || "";
	my($inst_dynamic_dep) = $attribs{INST_DYNAMIC_DEP} || "";
	my @m;
	push @m, "OTHERLDFLAGS = $otherldflags\n";
	push @m, "INST_DYNAMIC_DEP = $inst_dynamic_dep\n";
    if ($] < 5.00450) {
	push @m, '
$(INST_DYNAMIC) : $(INST_STATIC) $(PERL_INC)perlshr_attr.opt rtls.opt $(INST_ARCHAUTODIR).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(INST_DYNAMIC_DEP)
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) If F$TrnLNm("PerlShr").eqs."" Then Define/NoLog/User PerlShr Sys$Share:PerlShr.',$Config::Config{'dlext'},'
	Lnproc $(MMS$TARGET)$(OTHERLDFLAGS) $(BASEEXT).opt/Option,rtls.opt/Option,$(PERL_INC)perlshr_attr.opt/Option i
';
  } else {
	push @m, '
$(INST_DYNAMIC) : $(INST_STATIC) $(PERL_INC)perlshr_attr.opt $(INST_ARCHAUTODIR).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(INST_DYNAMIC_DEP)
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) If F$TrnLNm("PerlShr").eqs."" Then Define/NoLog/User PerlShr Sys$Share:PerlShr.',$Config::Config{'dlext'},'
	Lnproc $(MMS$TARGET)$(OTHERLDFLAGS) $(BASEEXT).opt/Option,$(PERL_INC)perlshr_attr.opt/Option i
';
    
  }
	push @m, $self->dir_target('$(INST_ARCHAUTODIR)');
	join('',@m);
    }

}


sub check_security {
    # check for the SUID/SGID bits on ORACLE_HOME/bin/oratclsh
    # if set, this allows a user to fork a root shell!
    # Get the octal portion of perms that indicates
    # SUID and SGID, and warn if either is set
 
    my @files = map { ($_,$_.'0') } qw(
	oratclsh lsnrctl oemevent onrsd osslogin tnslsnr
	tnsping trcasst trcroute cmctl cmadmin cmgw names namesctl otrccref
	otrcfmt otrcrep otrccol
    );

    my @bad;
    foreach (@files) {
	my $file = "$ENV{ORACLE_HOME}/bin/$_";
	my ($mode) = (stat($file))[2];
	next unless defined $mode;
	push @bad, $file if ($mode & 04000 and $mode & 00111)
			 or ($mode & 02000 and $mode & 00111);
    }
    return unless @bad;

    print "\n";
    warn "***  WARNING - YOUR ORACLE INSTALLATION HAS A SECURITY PROBLEM.$BELL\n";
    warn "     Read the README.sec file for more information and patch details.$BELL\n";
    warn "     This is just a warning. It does not affect DBD::Oracle in any way.\n\n";
    sleep 6;
}

__END__
