#
# oradump.pl
#
# Dump the contents of an Oracle table into a set of insert statements.
# Usage:	oradump <base> <table> <user/password>
#
# Author:	Kevin Stock
# Date:		28th February 1992
#
eval 'use Oraperl; 1' || die $@ if $] >= 5;

$ora_debug = shift if $ARGV[0] =~ /^-#/;

(($base  = shift) &&
 ($table = shift) &&
 ($user  = shift)) || die "Usage: $0 base table user/password\n";

$lda = &ora_login($base, $user, '')		|| die $ora_errstr;
$csr = &ora_open($lda, "select * from $table")	|| die $ora_errstr;

while (@data = &ora_fetch($csr))
{
    print "insert into $table values('" . join("', '", @data) . "');\n";
}
warn "$ora_errstr" if $ora_errno;

&ora_close($csr)	|| die $ora_errstr;
&ora_logoff($lda)	|| die $ora_errstr;
