#
# tabinfo
#
# 	Usage:	tabinfo base user password table
#
# Displays the structure of the specified table.
# Note that the field names are restricted to the length of the field.
# This is mainly to show the use of &ora_lengths, &ora_titles and &ora_types.
#
eval 'use Oraperl; 1' || die $@ if $] >= 5;

# set debugging, if requested
#
$ora_debug = shift if $ARGV[0] =~ /-#/;

# read the compulsory arguments
#
(($base = shift)	&&
 ($user = shift)	&&
 ($pass = shift)	&&
 ($table = shift))	|| die "Usage: $0 base user password table ...\n";

# we need this for the table of datatypes
#
require 'oraperl.ph';

format STDOUT_TOP =
Structure of @<<<<<<<<<<<<<<<<<<<<<<<
$table

Field name                                    | Length | Type | Type description
----------------------------------------------+--------+------+-----------------
.

format STDOUT =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< | @>>>>> | @>>> | @<<<<<<<<<<<<<<<
$name[$i], $length[$i], $type[$i], $ora_types{$type[$i]}
.

$lda = &ora_login($base, $user, $pass) || die $ora_errstr . "\n";

do
{
	$csr = &ora_open($lda, "select * from $table") || die "$ora_errstr\n";

	(@name = &ora_titles($csr, 0)) || die $ora_errstr . "\n";
	(@length = &ora_lengths($csr)) || die $ora_errstr . "\n";
	(@type = &ora_types($csr)) || die $ora_errstr . "\n";

	foreach $i (0 .. $#name)
	{
		write;
	}

	&ora_close($csr);

	$- = 0;
} while ($table = shift);

&ora_logoff($lda);
