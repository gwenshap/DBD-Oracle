#!/usr/local/bin/perl -sw
# $Id: Makefile.PL,v 1.39 1996/05/30 13:49:31 timbo Exp $

require 5.002;

use ExtUtils::MakeMaker 5.16, qw(&WriteMakefile $Verbose);
use Getopt::Std;
use Config;
use strict;

# Some MakeMaker's forged some FileHandle methods
require FileHandle unless defined(&FileHandle::new);

use DBI 0.69;	# This DBI must be installed before we can build a DBD

my %opts = (
    NAME => 'DBD::Oracle',
    VERSION_FROM => 'Oracle.pm',
    dist  => { DIST_DEFAULT=> 'clean distcheck disttest ci tardist',
                PREOP => '$(MAKE) -f Makefile.old distdir' },
);
my(@MK, %MK, $MK);	# parsed macros from Oracle proc.mk file

# Options, typically only used for debugging
$::opt_m = '';		# path to proc.mk or oracle.mk file to read

getopts('m:') or die "Invalid arguments";

# --- Introduction

print "\nConfiguring DBD::Oracle ...\n";
print "\n>>>\tRemember to actually *READ* the README file!\n\n";

# --- Where is Oracle installed...

unless ($ENV{ORACLE_HOME}){
    warn "\$ORACLE_HOME not defined. Searching for Oracle...\n";
    foreach(qw(/usr/oracle /opt/oracle /usr/soft/oracle)){
	$ENV{ORACLE_HOME}=$_,last if -d "$_/rdbms/lib";
    }
    die "Unable to determine ORACLE_HOME" unless $ENV{ORACLE_HOME};
}
my $OH = $ENV{ORACLE_HOME};

print "Using Oracle in $OH\n";


# --- What Oracle is installed...

# Todo: validate we have the right stuff installed
# Todo: add depend's for DBIXS etc
# e.g., Oracle 7.x, Pro*C etc. How do we test for those?

# XXX out of date for Oracle 7.3.2. Sigh.
warn "Warning: OCI (Pro*C) does not appear to be installed.\n"
	unless -f "$OH/lib/libocic.a"
	   and -f "$OH/rdbms/demo/oratypes.h";

# read list of libs that oracle requires (eg -lm -lnsl)
my $sysliblist = `cat $OH/rdbms/lib/sysliblist`;
chomp $sysliblist;
print "Oracle sysliblist: $sysliblist\n";


my @mkfiles;
my $oraclemk = $::opt_m || "$OH/proc/lib/proc.mk";
$oraclemk = "$OH/precomp/demo/proc/proc.mk" unless -f $oraclemk; # 7.3.x
$oraclemk = "$OH/proc16/lib/proc16.mk" unless -f $oraclemk;
die "Unable to locate proc.mk (use -m /path/to/proc.mk to specify)\n"
    unless -f $oraclemk;

my $linkwith = fetch_oci_macros();
 
print "Using @mkfiles ".($MK{mkver} ? "(version $MK{mkver})" : '')."\n";

$linkwith = expand_mkvars($linkwith, 0);
$linkwith =~ s/-Y P,/-YP,/ if $Config{'cc'} =~ /gcc/;

my $OCIINCLUDE = $MK{INCLUDE} || '';

$opts{LIBS} = [ $sysliblist ];
# INSTALLARCHLIB included _after_ INSTALLSITEARCH for transition period
$opts{INC}  = "$OCIINCLUDE -I$OH/rdbms/demo -I\$(INSTALLSITEARCH)/DBI -I\$(INSTALLARCHLIB)/DBI";
$opts{dynamic_lib} = { OTHERLDFLAGS => '-L$(LIBHOME) $(COMPOBJS) '.$linkwith };
$opts{OBJECT} = '$(O_FILES)';



# --- Handle special cases ---

# HP-UX 9 cannot link a non-PIC object file into a shared library.
# Since the # .a libs that Oracle supplies contain non-PIC object
# files, we sadly have to build static on HP-UX 9 :(
if ($Config{osname} eq 'hpux' and $Config{osver} < 10) {
    print "Warning: forced to build static not dynamic on $Config{osname} $Config{osver}\n";
    print "         See README and Makefile.PL for more information.\n";
    $opts{LINKTYPE} = 'static';
}

$opts{DEFINE} = '-Wall -pedantic -Wno-comment -Wtraditional'
	if $Config{cc} eq 'gcc';

$opts{DEFINE} .= '-Xa' if $Config{cc} eq 'clcc';	# CenterLine CC


# Set some private WriteMakefile options if this is 'me' :-)
if ($ENV{LOGNAME} eq 'timbo' and $ENV{S_ARCH_SW}){  # a reasonable guess
    $Verbose = 1;
    $opts{INST_LIB}     = '$(INSTALLSITELIB)';
    $opts{INST_ARCHLIB} = '$(INSTALLSITEARCH)';
	$opts{DEFINE} .= ' -Wcast-align -Wconversion -Wpointer-arith'
	    . ' -Wbad-function-cast -Wcast-qual' if $Config{cc} eq 'gcc';
}

# log key platform information to help me help you quickly
print "System: perl$] @Config{qw(myuname)}\n";
print "Compiler: @Config{qw(cc optimize ccflags)}\n";
print "Oracle proc.mk would have used these values but we override them:\n";
print "  CC:       $MK{CC}\n"		if $MK{CC};
print "  CFLAGS:   $MK{CFLAGS}\n"	if $MK{CFLAGS};
print "  LDFLAGS:  $MK{LDFLAGS}\n"	if $MK{LDFLAGS};
print "  LDSTRING: $MK{LDSTRING}\n"	if $MK{LDSTRING};
print "Linking with $linkwith\n";

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

    # Read $oraclemk makefile, extract macro definitions from it
    # and store them in $MK, @MK and %MK.

    # Don't include the following definitions in the generated
    # makefile (note that %MK stills gets these values).
    my @edit = qw(SHELL CC CFLAGS ASFLAGS RCC LDFLAGS AR ECHO EXE OBJS);
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
    my @lines = read_inc_file($oraclemk);
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
	die "ERROR parsing $oraclemk: Unable to determine what to link with.\n";
    }
    $MK = join("\n", @MK);
    $linkwith;
}

sub read_inc_file {
    my $file = shift;
    my $fh = new FileHandle "<$file" or die "Unable to read $file: $!";
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

sub expand_mkvars { 
    my $string = shift;
    my $strip  = shift;
    # warn "Expanding: $string\n";
    $string =~ s/\$\((\w+)\)/mkvar($1, $strip)/ge;
    $string =~ s/\s*\\\n\s*/ /g;	# merge continuations
    $string =~ s/\s+/ /g;			# shrink whitespace
    $string;
}
sub mkvar { 
    my $var = shift;
    my $strip = shift;
    my $default = $strip ? '' : "\$($var)";
    # warn "Expand var: $var\n";
    return $default if $var eq 'LIBHOME';
    return $ENV{ORACLE_HOME} if $var eq 'ORACLE_HOME';
    $MK{$var} ? expand_mkvars($MK{$var}, $strip) : $default;
}

__END__
