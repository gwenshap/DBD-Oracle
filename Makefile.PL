# $Id: Makefile.PL,v 1.68 1998/08/14 18:07:46 timbo Exp $

BEGIN { $^W = 1 }
BEGIN { require 5.003 }	# 5.003 fixes very important bugs

use ExtUtils::MakeMaker 5.16, qw(&WriteMakefile $Verbose);
use Getopt::Long;
use Config;
use Cwd;
use File::Find;
use strict;

# Some MakeMaker's forged some FileHandle methods
require FileHandle unless defined(&FileHandle::new);

BEGIN { if ($^O eq 'VMS') {
    require vmsish;
    import  vmsish;
    require VMS::Filespec;
    import  VMS::Filespec;
}}

# This DBI must be installed before we can build a DBD.
# For those not using Dynamic loading this means building a
# new static perl in the DBI directory by saying 'make perl'
# and then using _that_ perl to make this one.
use DBI 0.92;
use DBI::DBD;	# DBD creation tools

my $dbi_dir      = dbd_dbi_dir();
my $dbi_arch_dir = dbd_dbi_arch_dir();
my $os = $^O;
my $osvers = $Config{osvers};
$osvers =~ s/^\s*(\d+\.\d+).*/$1/;	# drop sub-sub-version: 2.5.1 -> 2.5

my %opts = (
    NAME => 'DBD::Oracle',
    VERSION_FROM => 'Oracle.pm',
    EXE_FILES => [ 'ora_explain' ],
    OBJECT => '$(O_FILES)',
    DEFINE => '',
    DIR  => [],
    clean => {	FILES=> 'Oracle.xsi' },
    dist  => {	DIST_DEFAULT	=> 'clean distcheck disttest ci tardist',
		PREOP		=> '$(MAKE) -f Makefile.old distdir',
		COMPRESS	=> 'gzip -v9', SUFFIX => 'gz',
    },
);
if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR} = 'Tim Bunce (dbi-users@fugue.com)';
    $opts{ABSTRACT_FROM} = 'Oracle.pm';
    $opts{PREREQ_PM} = { DBI => 0 };
    $opts{CAPI} = 'TRUE' if $Config{archname} =~ /-object\b/i;
}

$opts{LINKTYPE} = 'static' if $Config{dlsrc} =~ /dl_none/;

my(@MK, %MK, $MK, %MK_expanding);	# parsed macros from Oracle's makefiles

# Options (rarely needed)
$::opt_m = 0;	# path to proc.mk or oracle.mk file to read
$::opt_c = 0;	# don't encourage use of shared library
$::opt_n = '';	# Oracle .mk macro name to use for library list to link with
$::opt_p = '';	# alter preference for oracle.mk over proc
$::opt_l = 0;	# try direct-link to libclntsh
$::opt_g = '';	# enable debugging (-g for compiler and linker)
$::opt_s = '';	# Find a symbol in oracle libs, Don't build a Makefile
$::opt_S = '';	# Find a symbol in oracle & system libs, Don't build a Makefile
$::opt_v = 0;	# be more verbose
$::opt_d = 0;	# much more verbose for debugging

GetOptions(qw(v! d! g! p! l! c! m=s n=s s=s S=s))
	or die "Invalid arguments";

$::opt_g &&= '-g';	# convert to actual string
$::opt_v = 1 if $::opt_d;
$Verbose = 1 if $::opt_v;


# --- Introduction

print "\n Configuring DBD::Oracle ...\n
>>>\tRemember to actually *READ* the README file!
   \tEspecially if you have any problems.\n
" unless $::opt_s;


# --- Where is Oracle installed...

my $ORACLE_ENV  = ($os eq 'VMS') ? 'ORA_ROOT' : 'ORACLE_HOME';

my $OH = $ENV{$ORACLE_ENV};
$OH =~ s:\\:/:g               if $os eq 'MSWin32';
($OH = unixify $OH) =~ s:/$:: if $os eq 'VMS';
die "$ORACLE_ENV environment variable must be set.\n" unless $OH;
die "$ORACLE_ENV environment variable ($OH) not valid.\n" unless -d $OH;

print "Using Oracle in $OH\n";

my (@inspdver, %inspdver);
if ($os ne 'VMS' and $os ne 'MSWin32' and -x "$OH/orainst/inspdver") {
    open INST, "$OH/orainst/inspdver |";
    my @inspdver = <INST>;
    close INST;
    $inspdver{RDBMS} = 0;
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
	print "DBD::Oracle for Oracle $inspdver{RDBMS} on HP-UX may not build ok.\n";
	print "If your have problems read the README (in fact, read it anyway!)\n";
	print "An upgrade to Oracle 7.3.3 is probably a good idea.\n";
	sleep 5;
    }
}

symbol_search() if $::opt_s or $::opt_S;


# --- How shall we link with Oracle? Let me count the ways...

my @mkfiles;
my $linkwith;
my $linkwith_msg;

if ($os eq 'VMS') {
    my $OCIINCLUDE = vmsify("$OH/rdbms/") ." ". vmsify("$OH/rdbms/demo/oci_demo/");
    $opts{INC}  = "$OCIINCLUDE $dbi_arch_dir";
    $opts{OBJECT} = 'oracle.obj dbdimp.obj';
}

elsif ($os eq 'MSWin32') {
    my $OCIDIR = "";
    find( sub {
	print "Found $_\n" if /^OCI\d+/i;
	$OCIDIR = $_ if /^OCI\d\d$/i && $OCIDIR lt $_;
	$File::Find::prune = 1 if -d $_ && $_ ne "." && $_ ne "..";
    }, $OH );
    print "Using OCI directory: $OCIDIR\n";

    my $oci_compiler_dir = ($Config{cc} eq 'bcc32' ? "BORLAND" : "MSVC");
    die qq{
    Unable to find required Oracle OCI files for the build.  Please check
    that you have your OCI installed in your oracle home ($OH) 
    directory and that it has the following files (and probably more):

	$OH\\$OCIDIR\\include\\oratypes.h
	$OH\\$OCIDIR\\lib\\$oci_compiler_dir\\ociw32.lib

    Please install OCI or send comments back to dbi-users\@fugue.com you 
    have an OCI directory other than $OCIDIR.  

    } unless  (-e "$OH/$OCIDIR/include/oratypes.h" 
	    && -e "$OH/$OCIDIR/lib/$oci_compiler_dir/ociw32.lib");

    my $OCIINCLUDE = "-I$OH/$OCIDIR/include -I$OH/rdbms/demo";
    $opts{LIBS} = [ "-L$OH/$OCIDIR/LIB/$oci_compiler_dir OCIW32" ];
    $opts{SKIP} = ['processPL'];    # XXX added because it caused problems with Nmake...
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
    my $syslibs =   (-f "$OH/lib/sysliblist")
	    ? read_file("$OH/lib/sysliblist")
	    : read_file("$OH/rdbms/lib/sysliblist");
    $syslibs =~ s/-l:lib(\w+).(sl|a)\b/-l$1/g if $os eq 'hpux';
    print "Oracle sysliblist: $syslibs\n";
    $opts{LIBS} = [ "-L$OH/lib -l$lib $syslibs" ];
    $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g" };
    my $inc = join " ", map { "-I$OH/$_" } find_headers();
    $opts{INC}  = "$inc -I$dbi_arch_dir";
}
else {	# --- trawl the guts of Oracle's make files looking the how it wants to link

    my @ora_libs = <$OH/lib/lib*>;
    warn "\nYou don't seem to have many Oracle libraries installed. If the"
	."\nbuild fails you probably need to install more Oracle software.\n\n"
	if @ora_libs < 6; # just a helpful hint

    # can we give the shared library a helping hand?
    my @shared = grep { m:/lib(cl(ie)?ntsh|oracle).\w+$:o } @ora_libs;
    # show original value of ORA_CLIENT_LIB if defined ...
    print "\$ORA_CLIENT_LIB=$ENV{ORA_CLIENT_LIB}\n"
		if defined $ENV{ORA_CLIENT_LIB};
    # ... before we then set it how it probably should be set
    $ENV{ORA_CLIENT_LIB} = 'shared'
		if !defined $ENV{ORA_CLIENT_LIB}
		&& ($opts{LINKTYPE}||'') ne 'static' && @shared && !$::opt_c;

    my $mkfile = find_mkfile();
    my $linkvia = fetch_oci_macros($mkfile);
    my $libhome = expand_mkvars($MK{LIBHOME}, 0, 1) || "$OH/lib";
    $linkwith = expand_mkvars($linkvia, 0, 1);
    $linkwith =~ s/-Y P,/-YP,/g if $Config{'cc'} =~ /gcc/;
    $linkwith =~ s:-R /:-R/:g if $os eq 'solaris';

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
    $linkwith_s .= " -lc" if $Config{archname} eq 'i386-dynixptx';
    if ($os eq 'solaris' and $osvers >= 2.3 and $linkwith_s =~ /-lthread/) {
	print "Warning: Solaris 2.5 bug #1224467 may cause '_rmutex_unlock' error.\n";
	print "Deleting -lthread from link list as a possible workround.\n";
	$linkwith_s =~ s/\s*-lthread\b/ /g;
    }

    # extract object files, keep for use later
    my @linkwith_o;
    push @linkwith_o, $1 while $linkwith_s =~ s/(\S+\.[oa])\b//;
    # also extract AIX .exp files since they confuse MakeMaker
    push @linkwith_o, $1 while $linkwith_s =~ s/(-bI:\S+\.exp)\b//;

    $linkwith_msg = "@linkwith_o $linkwith_s [from $linkvia]";
    my $OCIINCLUDE = $MK{INCLUDE} || '';
    $OCIINCLUDE .= " -I$OH/rdbms/demo";
    $opts{LIBS} = [ "-L$libhome $linkwith_s" ];
    my $compobj = '$(COMPOBJS)';
    $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g @linkwith_o $compobj" };
    my $inc = join " ", map { "-I$OH/$_" } find_headers();
    $opts{INC}  = "$OCIINCLUDE $inc -I$dbi_arch_dir";
}


# --- Handle special cases ---

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($os eq 'hpux') {
	if ($osvers < 10) {
		print "Warning: Forced to build static not dynamic on $os $osvers.\a\n";
		$opts{LINKTYPE} = 'static';
	}
	else {
		print "Warning: You may need to build using static linking. See the README file.\n";
	}
	# see const_cccmd for -Aa to -Ae flag change
}

if ($os eq 'aix' and $osvers >= 4 and $Config{cc} ne 'xlc_r') {
    print "Warning: You may need to rebuild perl using the xlc_r compiler.\a\n";
    print "         You may also need do: ORACCENV='cc=xlc_r'; export ORACCENV\n";
}

$opts{DEFINE} .= '-Wall -Wno-comment' if $Config{cc} eq 'gcc';

$opts{DEFINE} .= '-Xa' if $Config{cc} eq 'clcc';	# CenterLine CC

print "WARNING: Your GNU C compiler is very old. Please upgrade.\n"
    if ($Config{gccversion} and $Config{gccversion} =~ m/^(1|2\.[1-5])/);

# Set some private WriteMakefile options if this is 'me' :-)
if ($ENV{LOGNAME} eq 'timbo' and $ENV{S_ARCH_SW}){  # a reasonable guess
    $Verbose = 1;
    $opts{DEFINE} .= ' -Wcast-align -Wconversion -Wpointer-arith -pedantic -Wtraditional'
	. ' -Wbad-function-cast -Wcast-qual' if $Config{cc} eq 'gcc';
	$::opt_g = '-g';
    $opts{dynamic_lib}->{OTHERLDFLAGS} ||= '';
    $opts{dynamic_lib}->{OTHERLDFLAGS} .= " $::opt_g";
}

if ($opts{LINKTYPE} && $opts{LINKTYPE} eq 'static') {
    print "** Note: DBD::Oracle will be built *into* a NEW perl binary. You MUST use that new perl.\n";
    print "         See README and Makefile.PL for more information.\a\n";
}


# --- final information dumps and generation of the Makefile

# log key platform information to help others help you quickly if needed
print "\n";
print "System: perl$] @Config{qw(myuname)}\n";
print "Compiler: @Config{qw(cc optimize ccflags)}\n";
print "Linker:   ". (find_bin('ld')||"not found") ."\n" unless $os eq 'VMS';
print "Oracle makefiles would have used these values but we override them:\n"
	if $MK{CFLAGS} || $MK{LDFLAGS} || $MK{LDSTRING};
print "  CC:       $MK{CC}\n"	if $MK{CC};
print "  CFLAGS:   $MK{CFLAGS}\n"                  if $MK{CFLAGS};
print "           [".mkvar('CFLAGS',1,0,0).  "]\n" if $MK{CFLAGS};
print "  CLIBS:    $MK{CLIBS}\n"                   if $MK{CLIBS};
print "           [".mkvar('CLIBS',1,0,0).   "]\n" if $MK{CLIBS};
print "  LDFLAGS:  $MK{LDFLAGS}\n"                 if $MK{LDFLAGS};
print "           [".mkvar('LDFLAGS',1,0,0). "]\n" if $MK{LDFLAGS};
print "  LDSTRING: $MK{LDSTRING}\n"                if $MK{LDSTRING};
print "           [".mkvar('LDSTRING',1,0,0)."]\n" if $MK{LDSTRING};
print "\nLinking with $linkwith_msg\n" if $linkwith_msg;
print "\n";

WriteMakefile(%opts);

exit 0;


# =====================================================================


sub MY::post_initialize {
    my $self = shift;

    if (-f "$Config{installprivlib}/DBD/Oraperl.pm"){ # very old now
	print "
Please note: the Oraperl.pm installation location has changed.
It was: $Config{installprivlib}/DBD/Oraperl.pm
Is now: $Config{installprivlib}/Oraperl.pm
You have an old copy which you should delete when installing this one.\n";
    }

    if ($Config{privlibexp} ne $Config{sitelibexp}) {
        print "
Warning: By default new modules are installed into your 'site_lib'
directories. Since site_lib directories come after the normal library
directories you must delete any old DBD::Oracle files and directories from
your 'privlib' and 'archlib' directories and their auto subdirectories.
";
	if ( $os ne 'VMS' ) {
	    my ( $sl_exp, $sa_exp, $pl_exp, $al_exp, %old );
	    ( $sl_exp = $Config{sitelibexp} )  =~ s:\\:/:g; 
	    ( $sa_exp = $Config{sitearchexp} ) =~ s:\\:/:g; 
	    ( $pl_exp = $Config{privlibexp} )  =~ s:\\:/:g; 
	    ( $al_exp = $Config{archlibexp} )  =~ s:\\:/:g; 
	    my $wanted = sub {
		$File::Find::prune = ($File::Find::name eq $sl_exp ||
				      $File::Find::name eq $sa_exp ) && -d $_;
		$old{$File::Find::name} = 1
		    if ! $File::Find::prune && /^Oracle/;
	    };
	    find( $wanted, $pl_exp, $al_exp );
	    print "Here's a list of probable old files and directories:\n ",
		join( "\n ", sort keys %old ), "\n" if keys %old;
	    print "\n";
	}
    }

    # Ensure Oraperl.pm and oraperl.ph are installed into top lib dir
    $self->{PM}->{'Oraperl.pm'} = '$(INST_LIB)/Oraperl.pm';
    $self->{PM}->{'oraperl.ph'} = '$(INST_LIB)/oraperl.ph';

    # Add $linkwith to EXTRALIBS for those doing static linking
    $self->{EXTRALIBS} .= " -L\$(LIBHOME) $linkwith";

    '';
}


sub MY::postamble {
	return dbd_postamble(@_);
}


sub del_crtobj {
    my $orig = shift;
	my $str;
    # E.g. for changing the COMPOBJS line (and sometimes LDSTRING)
    # old: COMPOBJS=$(COMPOBJ)/crti.o $(COMPOBJ)/crt1.o $(COMPOBJ)/__fstd.o
    # new: COMPOBJS=$(COMPOBJ)/__fstd.o
    ($str = $orig) =~ s:[^\s=]*\bcrt[1in]\.o\b::g;
	print "del_crtobj: $orig\n          : $str\n"
		if $orig ne $str and $::opt_v;
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
    );
    my @mkplaces = ($::opt_p) ? @mk_proc : @mk_oci;
    if ($::opt_m) {
	$::opt_m = cwd()."/$::opt_m" unless $::opt_m =~ m:^/:;
	die "-m $::opt_m: not found" unless -f $::opt_m;
	unshift @mkplaces, $::opt_m;
    }
    my ($mkfile, $place);
    foreach $place (@mkplaces) {
	$place = "$OH/$place" unless $place =~ m:^[/\.]:; # abs or relative path
	next unless -f $place;
	push @mkfiles, $place;
	print "Found $place\n";
    }
    $mkfile = $mkfiles[0];	# use first one found
    if (!$mkfile and "@mkplaces" !~ m/oracle\.mk/) {
	print "Unable to locate a Pro*C *.mk. Falling back to oracle.mk.\n";
	$mkfile = "$OH/oracle.mk";
	push @mkplaces, $mkfile; # just for error message below
    }
    die qq{
	Unable to locate an oracle.mk or proc.mk file in your Oracle installation.
	(Looked in @mkplaces)

	The oracle.mk file is part of the Oracle RDBMS product. The
	proc.mk file is part of the Oracle Pro*C product.  You need to
	build DBD::Oracle on a system which has one of these installed.

	If your oracle.mk or proc.mk file is installed somewhere
	non-standard you can specify where it is using the -m option:
		perl Makefile.PL -m /path/to/your.mk

	See README.clients for more information and some alternatives.

    } unless ($os eq 'MSWin32') || ($os eq 'VMS') || ($mkfile && -f $mkfile);

    print "Using $mkfile\n";
    return $mkfile;
}


sub fetch_oci_macros {
    my $file = shift;

    # Read $file makefile, extract macro definitions from it
    # and store them in $MK, @MK and %MK.

    # Don't include the following definitions in the generated
    # makefile (note that %MK stills gets these values).
    my @edit = qw(
	SHELL CC CFLAGS CCFLAGS OPTIMIZE ASFLAGS RCC LD LDFLAGS
	AR ECHO EXE OBJS PERL OBJ_EXT LIB_EXT
    );
    my %edit; @edit{@edit} = ('$_ = ""') x @edit;

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

	next if m!^[-\w/+.\$()]+\s*:+[^=]*!; # skip targets
	next if m!^\t!;                      # skip target build rules
	next if m/^\s*\.SUFFIXES/;

	unless($MK{mkver}) {	# still want to get version number
	    my $line = $_; $line =~ s/[\\\r\n]/ /g;
	    $MK{mkver} = $mkver = $1
		if $line =~ m/\$Header:.*?\.mk.+(\d+\.\d+)/;
	}

	# We always store values into %MK before checking %edit
	# %edit can edit this in addition to $_ if needed.
	my $name;
	$MK{$1}= $' if m/^\s*(\w+)\s*=\s*/;
	$name = $1;

	$MK{$1} =~ s/^([^#]*)#.*/$1/ if $1 && $MK{$1}; # remove comments

	if ($name and exists $edit{$name}) {
	    my $pre = $_;
	    eval $edit{$name};	# execute code to edit $_
	    print "Edit $name ($edit{$name}) failed: $@\n" if $@;
	    if ($_ ne $pre and $::opt_v) {
		$_ ? print "Edited $name definition\n from: $pre\n   to: $_\n"
		   : print "Deleted $name definition: $pre\n";
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
		(($opts{LINKTYPE}||'') eq 'static' || $::opt_c)) {
	    $linkvia .= '$(DEF_ON) '   if $MK{DEF_ON};
	    $linkvia .= '$(SSCOREED) ' if $MK{SSCOREED};
	    $linkvia .= '$(OCISTATICLIBS)';
	}
	else {
	    $linkvia .= '$(SSDBED) '	if $MK{SSDBED};
	    $linkvia .= '$(DEF_OPT) '	if $MK{DEF_OPT};
	    $linkvia .= '$(OCISHAREDLIBS)';
	}
    }

    # The oracle.mk file tends to define OCILDLIBS
    $linkvia = '$(OCILDLIBS)'
	if !$linkvia && $MK{OCILDLIBS};

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
    $MK = join("\n", @MK);
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


sub expand_shellescape { 
    my($orig, $level) = @_;
    my $cmd = $orig;
	my $debug = $::opt_d || 1;
    print "Evaluating `$orig`\n" if $debug;
    # ensure we have no $(...) vars left - strip out undefined ones:
    $cmd =~ s/\$\((\w+)\)/mkvar("$1", 1, 0, $level+1)/ge;
    print "  expanded `$cmd`\n" if $debug and $cmd ne $orig;
    my $result = `$cmd`;
	chop $result;
    print "  returned '$result'\n" if $debug;
    $result;
}

sub expand_mkvars { 
    my($string, $strip, $backtick, $level) = @_;
	$level ||= 1;
    local($_) = $string;
    print "$level Expanding $_\n" if $::opt_d;
    # handle whizzo AIX make feature used by Oracle
    s/\$\( (\w+) \? ([^(]*?) : ([^(]*?) \)/
	my ($vname, $vT, $vF) = ($1,$2,$3);
	$MK{$vname} = (mkvar($vname, 1, $backtick, $level+1)) ? $vT : $vF
    /xge; # can recurse
    s/\$\( (\w+) \)/
	mkvar("$1", $strip, $backtick, $level+1)
    /xge; # can recurse
    s/`(.*?[^\\])`/expand_shellescape("$1", $level+1)/esg if $backtick; # can recurse
    s/\s*\\\n\s*/ /g;	# merge continuations
    s/\s+/ /g;		# shrink whitespace
    print "$level Expanded $string\n  to       $_\n\n" if $::opt_d and $_ ne $string;
    $_;
}


sub mkvar { 
    my($var, $strip, $backtick, $level) = @_;
    my $default = $strip ? '' : "\$($var)";
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
    return expand_mkvars($val, $strip, $backtick, $level+1); # can recurse
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
	return unless /^o(ci...|ratypes)\.h$/i;
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
	do echo "  searching oracle \$i ..."; nm \$i | grep $::opt_s; done
    });
    if ($::opt_S) {
	my @libpth = split ' ', $Config{libpth};
	print "Searching for symbol '$::opt_s' in @libpth ...\n";
	@libpth = map { ("$_/lib*.$dlext", "$_/lib*.a") } @libpth;
	system(qq{	cd $OH; for i in @libpth;
	    do echo "  searching \$i ..."; nm \$i | grep $::opt_s; done
	});
    }
    print "Search done.\n";
    print "(Please only include the 'interesting' parts when mailing.)\n";
    exit;
}


# =====================================================================


{
    package MY; # SUPER needs package context, $self is not sufficient


    sub post_constants {
	my $self = shift;
	# Oracle Definitions, based on $(ORACLE_HOME)/proc/lib/proc.mk
	# Please let me know if this does, or does not, work for you.
	'
###################################################################
#
ORACLE_HOME = '.$OH.'

# The following text has been extracted from '.join("\n#\t", '', @mkfiles).'

'.$MK.'

# End of extract from '."@mkfiles".'
#
###################################################################
';
    }


    sub const_cccmd {
	my($self) = shift;
	print "Using DBD::Oracle $self->{VERSION}.\n";

	local($_) = $self->SUPER::const_cccmd(@_);
	# If perl Makefile.PL *-g* then switch on debugging
	if ($::opt_g) {
	    s/\s-O\d?\b//;	# delete optimise option
	    s/\s-/ -g -/;	# add -g option
	}
	# are we using the non-bundled hpux compiler?
	if ($os eq "hpux" and $Config::Config{ccflags} =~ /-Aa\b/) {
	    print "Changing -Aa to -Ae for HP-UX.\n";
	    s/-Aa\b/-Ae/g;	# allow "long long" in oratypes.h
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
	push @m, '
$(INST_DYNAMIC) : $(INST_STATIC) $(PERL_INC)perlshr_attr.opt rtls.opt $(INST_ARCHAUTODIR).exists $(EXPORT_LIST) $(PERL_ARCHIVE) $(INST_DYNAMIC_DEP)
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) If F$TrnLNm("PerlShr").eqs."" Then Define/NoLog/User PerlShr Sys$Share:PerlShr.',$Config::Config{'dlext'},'
	Lnproc $(MMS$TARGET)$(OTHERLDFLAGS) $(BASEEXT).opt/Option,rtls.opt/Option,$(PERL_INC)perlshr_attr.opt/Option i
';
	push @m, $self->dir_target('$(INST_ARCHAUTODIR)');
	join('',@m);
    }

}

__END__
