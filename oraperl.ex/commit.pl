#!/usr/local/bin/oraperl
#
# commit.pl
#
# Simple example of using commit and rollback.

eval 'use Oraperl; 1' || die $@ if $] >= 5;

$ora_debug = shift if $ARGV[0] =~ /^-#/;

$lda = &ora_login('t', 'kstock', 'kstock') || die "$ora_errstr\n";
&ora_do($lda, 'create table primes (prime number)') || die "$ora_errstr\n";

$csr = &ora_open($lda, 'insert into primes values(:1)') || die "$ora_errstr\n";
print 'creating table';
while (<DATA>)
{
	chop;
	print " $_";
	&ora_bind($csr, $_) || die "$_: $ora_errstr\n";
	(print ' committing ', &ora_commit($lda)) if $_ == 11;
}
&ora_close($csr) || die "$ora_errstr\n";

print "\n\nReading table for the first time\n\n";
$csr = &ora_open($lda, 'select prime from primes') || die "$ora_errstr\n";
while (($prime) = &ora_fetch($csr))
{
	print "$prime ";
}
die "$ora_errstr\n" if $ora_errno;
&ora_close($csr) || die "$ora_errstr\n";

print "\n\nRolling back ", &ora_rollback($lda), "\n\n";

print "Attempting to read data for the second time.\n";
print "Only values up to 11 should appear.\n\n";
$csr = &ora_open($lda, 'select prime from primes') || die "$ora_errstr\n";
while (($prime) = &ora_fetch($csr))
{
	print "$prime ";
}
die "$ora_errstr\n" if $ora_errno;
&ora_close($csr) || die "$ora_errstr\n";

&ora_do($lda, 'drop table primes') || die "$ora_errstr\n";
&ora_logoff($lda);
print "\n"
__END__
2
3
5
7
11
13
17
19
23
29
