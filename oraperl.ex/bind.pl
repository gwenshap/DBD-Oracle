#
# bind.pl
#
# This shows how the ora_bind function may be used to implement a
# simple lookup script.

eval 'use Oraperl; 1' || die $@ if $] >= 5;

$ora_debug = shift if $ARGV[0] =~ /^-#/;

$lda = &ora_login('t', 'kstock', 'kstock')
	|| die $ora_errstr;
$csr = &ora_open($lda, 'select phone from telno where name = :1')
	|| die $ora_errstr;

while(<STDIN>)
{
	chop;
	&ora_bind($csr, $_)	|| die $ora_errstr;

	# Note that $phone is placed in brackets to give it array context
	# Without them, &ora_fetch() returns the number of columns available

	if (($phone) = &ora_fetch($csr))
	{
		print "$phone\n";
	}
	else
	{
		die $ora_errstr if $ora_errno;
		print "unknown\n";
	}
}

&ora_close($csr);
&ora_logoff($lda);
