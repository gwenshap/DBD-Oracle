#!/usr/local/bin/perl -sw
# $Id: Makefile.PL,v 1.49 1996/08/22 23:41:31 timbo Exp $

BEGIN { require 5.003 }	# 5.003 fixes very important bugs

use ExtUtils::MakeMaker 5.16, qw(&WriteMakefile $Verbose);
use Getopt::Std;
use Config;
use strict;

# Some MakeMaker's forged some FileHandle methods
require FileHandle unless defined(&FileHandle::new);

# This DBI must be installed before we can build a DBD.
# For those not using Dynamic loading this means building a
# new static perl in the DBI directory by saying 'make perl'
# and then using _that_ perl to make this one.
use DBI 0.71;

my %opts = (
    NAME => 'DBD::Oracle',
    VERSION_FROM => 'Oracle.pm',
    dist  => { DIST_DEFAULT=> 'clean distcheck disttest ci tardist',
                PREOP => '$(MAKE) -f Makefile.old distdir' },
);
my(@MK, %MK, $MK);	# parsed macros from Oracle proc.mk file

# Options, typically only used for debugging
$::opt_m = '';		# path to proc.mk or oracle.mk file to read
$::opt_g = '';		# enable debugging (s/-O/-g/g)
$::opt_s = '';		# Find a symbol, Don't build a Makefile
$::opt_v = 0;		# be verbose

getopts('gm:s:v') or die "Invalid arguments";

$::opt_g &&= '-g';	# convert to actual string

# --- Introduction


print "\n Configuring DBD::Oracle ...\n
>>>\tRemember to actually *READ* the README file!
   \tEspecially if you have any problems.\n
" unless $::opt_s;

# --- Where is Oracle installed...

unless ($ENV{ORACLE_HOME}){
    warn "\$ORACLE_HOME not defined. Searching for Oracle...\n";
    foreach(qw(/usr/oracle /home/oracle /opt/oracle)){
	$ENV{ORACLE_HOME}=$_,last if -d "$_/rdbms/lib";
    }
    die "Unable to determine ORACLE_HOME" unless $ENV{ORACLE_HOME};
}
my $OH = $ENV{ORACLE_HOME};

print "Using Oracle in $OH\n";


# --- What Oracle is installed...

warn "\nWARNING: Oracle OCI (Pro*C) does not appear to be installed.\n"
	."You must install Pro*C before you can build DBD::Oracle properly.\n\n"
    unless (-f "$OH/lib/libocic.a" and -f "$OH/rdbms/demo/oratypes.h")
	or (-f "$OH/precomp/demo/proc/proc.mk");	# 7.3.x
# XXX Todo: validate user has all the right Oracle stuff installed.

# Using -m to specify oracle.mk might work but is NOT supported.
my $procmk = $::opt_m || "$OH/proc/lib/proc.mk";
$procmk = "$OH/precomp/demo/proc/proc.mk" unless -f $procmk; # 7.3.x
$procmk = "$OH/proc16/lib/proc16.mk"      unless -f $procmk;
die q{
	Unable to locate proc.mk in your Oracle installation.

	proc.mk is part of the Oracle Pro*C product. You need to build
	DBD::Oracle on a system which has Oracle Pro*C installed.

	If proc.mk is installed somewhere non-standard you can use
		perl Makefile.PL -m /path/to/proc.mk
	to specify where it is.
} unless -f $procmk;

my @mkfiles;
my $linkwith = fetch_oci_macros();
my $libhome  = expand_mkvars($MK{LIBHOME}, 0, 1, 0) || "$OH/lib";
$linkwith    = expand_mkvars($linkwith,    0, 1, 0);
$linkwith =~ s/-Y P,/-YP,/g if $Config{'cc'} =~ /gcc/;
$linkwith =~ s:-R /:-R/:g if $Config{osname} eq 'solaris';

# get a cut down $linkwith to pass to MakeMaker liblist
my $linkwith_s = expand_mkvars($linkwith, 1, 1, 0);
# convert "/full/path/libFOO.a" into "-L/full/path -lFOO"
$linkwith_s =~ s!([/\w.]+)/lib(\w+).a!-L$1 -l$2!g;
# extract object files, keep for use later
my @linkwith_o;
push @linkwith_o, $1 while $linkwith_s =~ s/(\S+\.[oa])\b//;
# also extract AIX .exp files since they confuse MakeMaker
push @linkwith_o, $1 while $linkwith_s =~ s/(-bI:\S+\.exp)\b//;

if ($::opt_s) {
	warn "Searching for symbol '$::opt_s' in $OH ...\n";
	my $dlext = $Config{dlext};
	system(qq{	cd $OH; for i in lib/*.[ao] lib/*.$dlext */lib/*.[ao];
				do echo "  searching \$i ..."; nm \$i | grep $::opt_s;
				done
			});
	warn "Search done.\n";
	exit;
}

if ($Config{osname} eq 'solaris' and $Config{osvers} >= 2.3
		and $linkwith_s =~ /-lthread/) {
	warn "Warning: Solaris 2.5 bug #1224467 may cause '_rmutex_unlock' error.\n";
	warn "Deleting -lthread from link list as a possible workround.\n";
	$linkwith_s =~ s/\s*-lthread\b/ /g;
}

my $OCIINCLUDE = $MK{INCLUDE} || '';
$opts{LIBS} = [ "-L$libhome $linkwith_s" ];
# INSTALLARCHLIB included _after_ INSTALLSITEARCH for transition period
$opts{INC}  = "$OCIINCLUDE -I$OH/rdbms/demo -I\$(INSTALLSITEARCH)/DBI -I\$(INSTALLARCHLIB)/DBI";
$opts{dynamic_lib} = { OTHERLDFLAGS => "$::opt_g @linkwith_o \$(COMPOBJS)" };
$opts{OBJECT} = '$(O_FILES)';



# --- Handle special cases ---

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($Config{osname} eq 'hpux' and $Config{osvers} < 10) {
    print "Warning: forced to build static not dynamic on $Config{osname} $Config{osvers}\n";
    print "         See README and Makefile.PL for more information.\n";
    $opts{LINKTYPE} = 'static';
}

$opts{DEFINE} = '-Wall -pedantic -Wno-comment -Wtraditional'
	if $Config{cc} eq 'gcc';

$opts{DEFINE} .= '-Xa' if $Config{cc} eq 'clcc';	# CenterLine CC

warn "WARNING: Your GNU C compiler is very old. Please upgrade.\n"
    if ($Config{gccversion} and $Config{gccversion} =~ m/^(1|2\.[1-5])/);

# Set some private WriteMakefile options if this is 'me' :-)
if ($ENV{LOGNAME} eq 'timbo' and $ENV{S_ARCH_SW}){  # a reasonable guess
    $Verbose = 1;
    # $opts{INST_LIB}     = '$(INSTALLSITELIB)';
    # $opts{INST_ARCHLIB} = '$(INSTALLSITEARCH)';
	$opts{DEFINE} .= ' -Wcast-align -Wconversion -Wpointer-arith'
	    . ' -Wbad-function-cast -Wcast-qual' if $Config{cc} eq 'gcc';
}
$Verbose = 1 if $::opt_v;

# log key platform information to help me help you quickly
print "System: perl$] @Config{qw(myuname)}\n";
print "Compiler: @Config{qw(cc optimize ccflags)}\n";
print "Linker:   ". find_bin('ld') ."\n";
print "Oracle proc.mk would have used these values but we override them:\n";
print "  CC:       $MK{CC}\n"		if $MK{CC};
print "  CFLAGS:   $MK{CFLAGS}\n"	if $MK{CFLAGS};
print "  LDFLAGS:  $MK{LDFLAGS}\n"	if $MK{LDFLAGS};
print "  LDSTRING: $MK{LDSTRING}\n"	if $MK{LDSTRING};
print "Linking with @linkwith_o $linkwith_s\n";

# Assorted hints - these should be move to a hints subdirectory
#print "See README notes about SPARCompiler on Solaris\n"
#    if -d "/opt/SUNWspro/bin" and $Config{osname} eq 'solaris';

print "\n";

WriteMakefile(%opts);

exit 0;


sub MY::post_initialize {
    my $self = shift;

    if (-f "$Config{installprivlib}/DBD/Oraperl.pm"){ # very old now
	warn "
Please note: the Oraperl.pm installation location has changed.
It was: $Config{installprivlib}/DBD/Oraperl.pm
Is now: $Config{installprivlib}/Oraperl.pm
You have an old copy which you should delete when installing this one.\n";
    }

    if ($Config{privlibexp} ne $Config{sitelibexp}) {
        warn "
Warning: By default new modules are installed into your 'site_lib'
directories. Since site_lib directories come after the normal library
directories you must delete any old DBD::Oracle files and directories from
your 'privlib' and 'archlib' directories and their auto subdirectories.
";
        my $find = "find $Config{privlibexp} $Config{archlibexp} ";
        $find .= "-name 'Oracle*' -print | sort | uniq";
        if (open(FIND, "$find |")) {
            my @old;
            while(<FIND>) {
                next if m:^$Config{sitelibexp}/:;
                next if m:^$Config{sitearchexp}/:;
                chop;
                push @old, $_;
            }
            close(FIND);
            warn "Here's a list of probable old files and directories:\n ",
                    join("\n ",@old),"\n" if @old;
            warn "\n";
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
ORACLE_HOME = '.$ENV{ORACLE_HOME}.'

# The following text has been extracted from '."@mkfiles".'

'.$MK.'

# End of extract from '."@mkfiles".'
#
###################################################################
';
}


sub fetch_oci_macros {

    # Read $procmk makefile, extract macro definitions from it
    # and store them in $MK, @MK and %MK.

    # Don't include the following definitions in the generated
    # makefile (note that %MK stills gets these values).
    my @edit = qw(SHELL CC CFLAGS CCFLAGS OPTIMIZE ASFLAGS RCC LD LDFLAGS AR ECHO EXE OBJS);
    my %edit; @edit{@edit} = ('$_ = ""') x @edit;

    $edit{COMPOBJS} = q{
	    # Change the COMPOBJS line. (Some files use LIBHOME not COMPOBJ)
	    # old: $(COMPOBJ)/crti.o $(COMPOBJ)/crt1.o $(COMPOBJ)/__fstd.o
	    # new: $(COMPOBJ)/__fstd.o
	    s:\$\S+?/crt[1in]\.o\b::g;
	} if $Config{osname} eq 'solaris'; # and $Config{gccversion};

    my $mkver = 0;
    my $linkwith = '';
    my $lastline = '';
    my @lines = read_inc_file($procmk);
    for(1; $_ = shift(@lines); $lastline = $_){
	# Join split lines but retain backwack and newlines:
	$_ .= shift(@lines) while(m/\\[\r\n]+$/);
	chomp;
	push(@MK, '') if ($_ eq '' and $lastline ne '');
	next unless $_;
	last if m/^\w+\s*:/;	# gone too far, reached actual targets

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
	$MK{$1} = $2 if m/^\s*(\w+)\s*=\s*([\s\S]*)/;

	next if m/^\s*\.SUFFIXES/;

	if ($1 and exists $edit{$1}) {
	    my $name = $1;
	    eval $edit{$name};	# execute code to edit $_
	    warn "Edit $name ($edit{$name}) failed: $@\n" if $@;
	}

	push(@MK, $_);
    }

    if ($MK{OCILDLIBS}) {
	$linkwith = '$(OCILDLIBS)';

    } elsif (int($mkver) == 1) {
	if ($MK{LLIBOCIC}) {
	    $linkwith = '$(LLIBOCIC) $(TTLIBS)';
	} else {
	    warn "Warning: Guessing what to link with.\n";
	    $linkwith = '-locic $(TTLIBS)';	# XXX GUESS HACK
	}
    }
    elsif ($MK{PROLDLIBS}) {	# Oracle 7.3.x
	$linkwith = '$(PROLDLIBS)';
    }
    unless ($linkwith){
	die "ERROR parsing $procmk: Unable to determine what to link with.\n";
    }
    $MK = join("\n", @MK);
    return $linkwith;
}

sub read_inc_file {
    my $file = shift;
    my $fh = new FileHandle "<$file" or die "Unable to read $file: $!";
    print "Reading $file.\n";
    my @lines;
    push(@mkfiles, $file);
    while(<$fh>) {
	# soak up while looking for include directives
	push(@lines, $_), next
	    unless /^\s*include\s+(.*?)\s*$/m;
	$file = $1;
	# deal with "include $(ORACLE_HOME)/..."
	# (can't use expand_mkvars() here)
	$file =~ s/\$\(ORACLE_HOME\)/$ENV{ORACLE_HOME}/g;
	push(@lines, read_inc_file($file));
    }
    return @lines;
}

sub expand_shellescape { 
    my($orig, $level) = @_;
    my $cmd = $orig;
    warn "\n$level * Evaluating \`$orig\`\n" if $::opt_v;
    # ensure we have no $(...) vars left - strip out undefined ones:
    $cmd =~ s/\$\((\w+)\)/mkvar($1, 1, 0, $level+1)/ge;
    warn "\n$level * After reducing to \`$cmd\`\n" if $::opt_v and $cmd ne $orig;
    my $result = `$cmd`;
    warn "$level * Returned $result\n\n" if $::opt_v;
    $result;
}
sub expand_mkvars { 
    my($string, $strip, $backtick, $level) = @_;
    local($_) = $string;
    warn "$level Expanding $_\n" if $::opt_v;
    s/\$\((\w+)\)/mkvar($1, $strip, $backtick, $level+1)/ge;
    s/`(.*?[^\\])`/expand_shellescape($1, $level+1)/esg if $backtick;
    s/\s*\\\n\s*/ /g;	# merge continuations
    s/\s+/ /g;			# shrink whitespace
    warn "$level Expanded $string\n  to       $_\n\n" if $::opt_v and $_ ne $string;
    $_;
}
sub mkvar { 
    my($var, $strip, $backtick, $level) = @_;
    my $default = $strip ? '' : "\$($var)";
    warn "$level Variable: $var\n" if $::opt_v;
    return '$(LIBHOME)' if $var eq 'LIBHOME' && !$strip; # gets noisy
    return $ENV{ORACLE_HOME} if $var eq 'ORACLE_HOME';
    $MK{$var} ? expand_mkvars($MK{$var}, $strip, $backtick, $level+1) : $default;
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
	s/\s-O\d?\b/ -g/g if $::opt_g;
	$_;
    }

}

__END__
