# mkdb.pl
#
# Sample (c)oraperl program to create a new database and load data into it.
#
# Author:	Kevin Stock
# Date:		5th August 1991
#
# Modified to use curses functions if present.
#
# Date:		15th November 1991
#
# Modified to demonstrate NULL handling in &ora_bind and &ora_fetch()
#
# Date:		25th September 1992

# First make sure that we are running under some form of perl.

eval "echo 'You must specify oraperl or coraperl.' ; exit"
	if 0;

eval 'use Oraperl; 1' || die $@ if $] >= 5;

# make sure that we really are running (c)oraperl
die ("You should use oraperl, not perl\n") unless defined &ora_login;

# Set up debugging (hope the user has redirected this if we're
# going into curses!)
$ora_debug = shift if $ARGV[0] =~ /^-#/;

# get error codes
require('oraperl.ph');

# Arrange to use curses functions if they're available.
# (This is just showing off)

if (defined(&initscr) && &initscr())
{
    eval <<'____END_OF_CURSES_STUFF';

	$curses = 1;

	# functions used by the list function

	sub before
	{
		&erase();
		&standout();
		&addstr("Num  Name           Ext\n\n");
		&standend();
		$lineno = 1;
	}

	sub during
	{
		&addstr(sprintf("%2d   %-15s%3s\n", $lineno++, $name, $ext));
	}

	sub after
	{
		&standout();
		&move($LINES - 1, 0);
		&addstr("Press RETURN to continue.");
		&standend();
		&refresh();
		&getstr($dummy);
		&move($LINES - 1, 0);
		&addstr("                         ");
		&move($LINES - 1, 0);
		&refresh();
	}

____END_OF_CURSES_STUFF
}
else
{
    eval <<'____END_OF_PLAIN_STUFF';

	$curses = 0;

	format STDOUT_TOP =
	       Name         Ext
	       ====         ===
.

	format STDOUT =
	       @<<<<<<<<<   @>>
	       $name,       $ext
.

	# functions used by the list function

	sub before	{ $- = 0; }
	sub during	{ write; }
	sub after	{ 1; }

____END_OF_PLAIN_STUFF
}

# function to list the database

sub list
{
	local($csr, $name, $ext);

	do before();

	$csr = &ora_open($lda, $LIST)			|| die $ora_errstr;
	while (($name, $ext) = &ora_fetch($csr))
	{
		$name = '<-NULL->' unless defined($name);
		$ext = '<-NULL->' unless defined($ext);
		do during();
	}
	die $ora_errstr if ($ora_errno != 0);
	do ora_close($csr)				|| die $ora_errstr;

	do after();
}

# set these as strings to make the code more readable
$CREATE = "create table tryit (name char(10), ext number(3))";
$INSERT = "insert into tryit values (:1, :2)";
$LIST	= "select * from tryit order by name";
$DELETE	= "delete from tryit where name = :1";
$DELETE_NULL	= "delete from tryit where name is null";
$DROP	= "drop table tryit";

# create the database

$lda = &ora_login('t', 'kstock', 'kstock')	|| die $ora_errstr;
&ora_do($lda, $CREATE)				|| die $ora_errstr;

# put some data into it

$csr = &ora_open($lda, $INSERT)			|| die $ora_errstr;
while (<DATA>)
{
	m/(.*):(.*)/;
	$name = ($1 eq 'NULL') ? undef : $1;
	$ext = ($2 eq 'NULL') ? undef : $2;
	do ora_bind($csr, $name, $ext);
}
do ora_close($csr)				|| die $ora_errstr;

# check the result
do list();

# remove a few lines

$csr = &ora_open($lda, $DELETE)			|| die $ora_errstr;
foreach $name ('catherine', 'angela', 'arnold', 'julia')
{
	&ora_bind($csr, $name)			|| die $ora_errstr;
}
&ora_close($csr)				|| die $ora_errstr;
&ora_do($lda, $DELETE_NULL)			|| die $ora_errstr;

# check the result
do list();

# remove the database and log out
do ora_do($lda, $DROP)				|| die $ora_errstr;
do ora_logoff($lda)				|| die $ora_errstr;

do endwin() if $curses == 1;

# This is the data which will go into the database
__END__
julia:292
angela:208
NULL:999
larry:424
catherine:201
nonumber:NULL
randal:306
arnold:305
NULL:NULL
