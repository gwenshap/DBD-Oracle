# $Id: Makefile.PL,v 1.55 1997/06/20 21:18:11 timbo Exp $

BEGIN { require 5.003 }	# 5.003 fixes very important bugs

use ExtUtils::MakeMaker 5.16, qw(&WriteMakefile $Verbose);
use Getopt::Long;
use Config;
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
use DBI 0.84;

my $os = $^O;
my $osvers = $Config{osvers};
$osvers =~ s/^\s*(\d+\.\d+).*/$1/;	# drop sub-sub-version: 2.5.1 -> 2.5

my %opts = (
    NAME => 'DBD::Oracle',
    VERSION_FROM => 'Oracle.pm',
    dist  => { DIST_DEFAULT=> 'clean distcheck disttest ci tardist',
                PREOP => '$(MAKE) -f Makefile.old distdir' },
);
my(@MK, %MK, $MK);	# parsed macros from Oracle's makefiles

# Options (rarely needed)
$::opt_m = '';		# path to proc.mk or oracle.mk file to read
$::opt_p = '';		# prefer oracle.mk over proc
$::opt_g = '';		# enable debugging (s/-O/-g/g)
$::opt_s = '';		# Find a symbol, Don't build a Makefile
$::opt_v = 0;		# be more verbose
$::opt_d = 0;		# much more verbose for debugging
$::opt_old = 0;		# old style .mk file parsing

GetOptions(qw(v! d! g! old! p! m=s s=s)) or die "Invalid arguments";

$::opt_g &&= '-g';	# convert to actual string
$::opt_v = 1 if $::opt_d;
$Verbose = 1 if $::opt_v;

# --- Introduction

my $ORACLE_ENV  = ($^O eq 'VMS') ? 'ORACLE_ROOT' : 'ORACLE_HOME';

print "\n Configuring DBD::Oracle ...\n
>>>\tRemember to actually *READ* the README file!
   \tEspecially if you have any problems.\n
" unless $::opt_s;

# --- Where is Oracle installed...

my $OH = $ENV{$ORACLE_ENV};
die "$ORACLE_ENV environment variable must be set.\n" unless $OH;
die "$ORACLE_ENV environment variable ($OH) not valid.\n" unless -d $OH;

my $OCIDIR = "OCI73";	# For MSWin32. XXX what about 7.4 etc?

print "Using Oracle in $OH\n";


my @mkplaces = qw(
    rdbms/lib/oracle.mk rdbms/demo/oracle.mk
    proc/lib/proc.mk    precomp/demo/proc/proc.mk
    proc16/lib/proc16.mk
);
# if -p then remove oracle.mk from search list, prefer Pro*C
@mkplaces = grep { !m/oracle\.mk\b/ } @mkplaces if $::opt_p;
unshift @mkplaces, $::opt_m  if $::opt_m;
my($mkfile, $place);
foreach $place (@mkplaces) {
    $place = "$OH/$place" unless $place =~ m:^[./]:;
    $mkfile = $place if -f $place;
    last if $mkfile;
}
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

} unless ($os eq 'MSWin32') || ($mkfile && -f $mkfile);

my(@mkfiles, $linkvia, $libhome, $linkwith, $linkwith_s, @linkwith_o, $OCIINCLUDE);

if ($os ne 'MSWin32') {
    $linkvia  = fetch_oci_macros($mkfile);
    $libhome  = expand_mkvars($MK{LIBHOME}, 0, 1, 0) || "$OH/lib";
    $linkwith = expand_mkvars($linkvia,     0, 1, 0);
    $linkwith =~ s/-Y P,/-YP,/g if $Config{'cc'} =~ /gcc/;
    $linkwith =~ s:-R /:-R/:g if $os eq 'solaris';

    # get a cut down $linkwith to pass to MakeMaker liblist
    $linkwith_s = expand_mkvars($linkwith, 1, 1, 0);
    # convert "/full/path/libFOO.a" into "-L/full/path -lFOO"
    $linkwith_s =~ s!([/\w.]+)/lib(\w+).a!-L$1 -l$2!g;
    # extract object files, keep for use later
    push @linkwith_o, $1 while $linkwith_s =~ s/(\S+\.[oa])\b//;
    # also extract AIX .exp files since they confuse MakeMaker
    push @linkwith_o, $1 while $linkwith_s =~ s/(-bI:\S+\.exp)\b//;

    if ($::opt_s) {
	print "Searching for symbol '$::opt_s' in $OH ...\n";
	my $dlext = $Config{dlext};
	system(qq{	cd $OH; for i in lib/*.[ao] lib/*.$dlext */lib/*.[ao];
	    do echo "  searching \$i ..."; nm \$i | grep $::opt_s;
	    done
	});
	print "Search done.\n";
	exit;
    }

    if ($os eq 'solaris' and $osvers >= 2.3
				     and $linkwith_s =~ /-lthread/) {
	print "Warning: Solaris 2.5 bug #1224467 may cause '_rmutex_unlock' error.\n";
	print "Deleting -lthread from link list as a possible workround.\n";
	$linkwith_s =~ s/\s*-lthread\b/ /g;
    }

    $OCIINCLUDE = $MK{INCLUDE} || '';
    $OCIINCLUDE .= " -I$OH/rdbms/demo";
    $opts{LIBS} = [ "-L$libhome $linkwith_s" ] unless $os eq 'VMS';
    $opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g @linkwith_o \$(COMPOBJS)" };
    $opts{OBJECT} = '$(O_FILES)';
}
else {	# MSWin32
    # this assumes MSVC...
    $OCIINCLUDE = "-I$OH/$OCIDIR/include -I$OH/rdbms/demo";
    $opts{LIBS} = [ "-L$OH/$OCIDIR/LIB/MSVC/OCIW32.LIB"];
    $opts{dynamic_lib} = { OTHERLDFLAGS => " $OH/$OCIDIR/LIB/MSVC/OCIW32.LIB" };
    $opts{OBJECT} = '$(O_FILES)';
    $opts{SKIP} = ['processPL'];    # XXX caused problems with Nmake...
}

$opts{INC}  = "$OCIINCLUDE -I\$(INSTALLSITEARCH)/auto/DBI";

# --- Handle special cases ---

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($os eq 'hpux' and $osvers < 10) {
    $opts{LINKTYPE} = 'static';
    print "Warning: Forced to build static not dynamic on $os $osvers.\a\n";
    print "** Note: DBD::Oracle will be built *into* a NEW perl binary. You MUST use that new perl.\n";
    print "         See README and Makefile.PL for more information.\a\n";
}
if ($os eq 'hpux' and $osvers >= 10) {
	print "Warning: You may need to build using static linking. See the README file.\n\a";
}

if ($os eq 'aix' and $osvers >= 4 and $Config{cc} ne 'xlc_r') {
	print "Warning: You may need to rebuild perl using the xlc_r compiler.\a\n";
	print "         You may also need do: ORACCENV='cc=xlc_r'; export ORACCENV\n";
}

$opts{DEFINE} = '-Wall -pedantic -Wno-comment -Wtraditional'
	if $Config{cc} eq 'gcc';

$opts{DEFINE} .= '-Xa' if $Config{cc} eq 'clcc';	# CenterLine CC

print "WARNING: Your GNU C compiler is very old. Please upgrade.\n"
    if ($Config{gccversion} and $Config{gccversion} =~ m/^(1|2\.[1-5])/);

# Set some private WriteMakefile options if this is 'me' :-)
if ($ENV{LOGNAME} eq 'timbo' and $ENV{S_ARCH_SW}){  # a reasonable guess
    $Verbose = 1;
    $opts{DEFINE} .= ' -Wcast-align -Wconversion -Wpointer-arith'
	. ' -Wbad-function-cast -Wcast-qual' if $Config{cc} eq 'gcc';
}

# log key platform information to help me help you quickly
print "System: perl$] @Config{qw(myuname)}\n";
print "Compiler: @Config{qw(cc optimize ccflags)}\n";
print "Linker:   ". (find_bin('ld')||"not found") ."\n" unless $os eq 'VMS';
print "Oracle proc.mk would have used these values but we override them:\n";
print "  CC:       $MK{CC}\n"	if $MK{CC};
print "  CFLAGS:   $MK{CFLAGS}\n"                  if $MK{CFLAGS};
print "           [".mkvar('CFLAGS',1,0,0).  "]\n" if $MK{CFLAGS};
print "  LDFLAGS:  $MK{LDFLAGS}\n"                 if $MK{LDFLAGS};
print "           [".mkvar('LDFLAGS',1,0,0). "]\n" if $MK{LDFLAGS};
print "  LDSTRING: $MK{LDSTRING}\n"                if $MK{LDSTRING};
print "           [".mkvar('LDSTRING',1,0,0)."]\n" if $MK{LDSTRING};
print "\nLinking with @linkwith_o $linkwith_s [from $linkvia]\n";
print "\n";

WriteMakefile(%opts);

exit 0;


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
        my $find = "find $Config{privlibexp} $Config{archlibexp} ";
        $find .= "-name 'Oracle*' -print | sort | uniq";
        if ($os ne 'VMS' and open(FIND, "$find |")) {
            my @old;
            while(<FIND>) {
                next if m:^$Config{sitelibexp}/:;
                next if m:^$Config{sitearchexp}/:;
                chop;
                push @old, $_;
            }
            close(FIND);
            print "Here's a list of probable old files and directories:\n ",
                    join("\n ",@old),"\n" if @old;
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


sub MY::post_constants {
    my $self = shift;

    # Oracle Definitions, based on $(ORACLE_HOME)/proc/lib/proc.mk
    # Please let me know if this does, or does not, work for you.
    '
###################################################################
#
ORACLE_HOME = '.$OH.'

# The following text has been extracted from '."@mkfiles".'

'.$MK.'

# End of extract from '."@mkfiles".'
#
###################################################################
';
}


sub del_crtobj {
    # E.g. for changing the COMPOBJS line
    # old: $(COMPOBJ)/crti.o $(COMPOBJ)/crt1.o $(COMPOBJ)/__fstd.o
    # new: $(COMPOBJ)/__fstd.o
    s:\$\S+?/crt[1in]\.o\b::g;
}


sub fetch_oci_macros {
    my $file = shift;

    # Read $file makefile, extract macro definitions from it
    # and store them in $MK, @MK and %MK.

    # Don't include the following definitions in the generated
    # makefile (note that %MK stills gets these values).
    my @edit = qw(
		SHELL CC CFLAGS CCFLAGS OPTIMIZE ASFLAGS RCC LD LDFLAGS
		AR ECHO EXE OBJS PERL
	);
    my %edit; @edit{@edit} = ('$_ = ""') x @edit;

    $edit{COMPOBJS} = q{
	# Firstly a Solaris specific edit:
	del_crtobj() if $os eq 'solaris';
	
	# Delete any object files in COMPOBJS that don't actually exist
	my $of;
	foreach $of (split(/=|\s+/)) {
	    next if !$of or $of eq "COMPOBJS";
	    my $obj = expand_mkvars($of,0,0,0);
	    next if -e $obj;
	    print "Deleting $of from COMPOBJS because $obj doesn't exist.\n";
	    s:\Q$of::;
	} 
    };

    my $mkver = 0;
    my $linkwith = '';
    my $lastline = '';
    my @lines = read_inc_file($file);
    for(1; $_ = shift(@lines); $lastline = $_){
	# Join split lines but retain backwack and newlines:
	$_ .= shift @lines while(m/\\[\r\n]+$/);
	chomp;
	push @MK, '' if $_ eq '' and $lastline ne ''; # squeeze multiple blank lines
	next unless $_;

	if ($::opt_old) {
	    last if m/^\w+\s*:[^=]/;	# gone too far, reached actual targets
	}
	else {
	    next if m!^[-\w/+.\$()]+\s*:+[^=]*!; # skip targets
	    next if m!^\t!;                      # skip target build rules
	}
	next if m/^\s*\.SUFFIXES/;

	unless($MK{mkver}) {	# still need to get version number
	    # This is tough since some versions of proc.mk split the
	    # RCS header over three lines! Later versions don't even
	    # have one. That's Oracle for you.
	    my $line = $_;
	    $line =~ s/[\\\r\n]/ /g;
	    $MK{mkver} = $mkver = $1
		if $line =~ m/\$Header:.*?\.mk.+(\d+\.\d+)/;
	}

	# We always store values into %MK before checking %edit
	# %edit can edit this in addition to $_ if needed.
	my $name;
	if ($::opt_old) {
	    $MK{$1} = $2 if m/^\s*(\w+)\s*=\s*([\s\S]*)/;
	    $name = $1;
	}
	else {
	    $MK{$1}= $' if m/^\s*(\w+)\s*=\s*/;
	    $name = $1;
	}

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

    if ($MK{OCILDLIBS}) {
	$linkwith = '$(OCILDLIBS)';

    } elsif (int($mkver) == 1) {
	if ($MK{LLIBOCIC}) {
	    $linkwith = '$(LLIBOCIC) $(TTLIBS)';
	} else {
	    print "Warning: Guessing what to link with.\n";
	    $linkwith = '-locic $(TTLIBS)';	# XXX GUESS HACK
	}
    }
    elsif ($MK{PROLDLIBS}) {	# Oracle 7.3.x
	$linkwith = '$(PROLDLIBS)';
    }
    unless ($linkwith){
	die "ERROR parsing $file: Unable to determine what to link with.\n"
	."Please send me copies of these files (one per mail message):\n@mkfiles\n";
    }
    $MK = join("\n", @MK);
    return $linkwith;
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
    print "\n$level * Evaluating \`$orig\`\n" if $::opt_d;
    # ensure we have no $(...) vars left - strip out undefined ones:
    $cmd =~ s/\$\((\w+)\)/mkvar("$1", 1, 0, $level+1)/ge;
    print "\n$level * After reducing to \`$cmd\`\n" if $::opt_d and $cmd ne $orig;
    my $result = `$cmd`;
    print "$level * Returned $result\n\n" if $::opt_d;
    $result;
}
sub expand_mkvars { 
    my($string, $strip, $backtick, $level) = @_;
    local($_) = $string;
    print "$level Expanding $_\n" if $::opt_d;
    s/\$\((\w+)\)/mkvar("$1", $strip, $backtick, $level+1)/ge; # can recurse
    s/`(.*?[^\\])`/expand_shellescape("$1", $level+1)/esg if $backtick; # can recurse
    s/\s*\\\n\s*/ /g;	# merge continuations
    s/\s+/ /g;			# shrink whitespace
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
	    print "Using value of $var from environment: $val\n";
    }
    return $default unless defined $val;
    return expand_mkvars($val, $strip, $backtick, $level+1); # can recurse
}

sub find_bin{
    my $bin = shift;
    foreach(split(/:/, $ENV{PATH})){
	return "$_/$bin" if -x "$_/$bin";
    }
    return "<$bin not found>";
}

{	# If perl Makefile.PL *-g* then switch on debugging
    package MY; # SUPER needs package context, $self is not sufficient
    sub const_cccmd {
	my($self) = shift;
	local($_) = $self->SUPER::const_cccmd(@_);
	if ($::opt_g) {
	    s/\s-O\d?\b//;	# delete optimise option
	    s/\s-/ -g -/;	# add -g option
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
