#

eval 'use Oraperl; 1' || die $@ if $] >= 5;

$ora_debug = shift if $ARGV[0] =~ /^-#/;

format STDOUT_TOP =
       Name                           Phone
       ====                           =====
.

format STDOUT =
       @<<<<<<<<<<              @>>>>>>>>>>
       $name,                   $phone
.

die ("You should use oraperl, not perl\n") unless defined &ora_login;

$lda = &ora_login("t", "kstock", "kstock")
	|| die $ora_errstr;
$csr = &ora_open($lda, "select * from telno order by name", 6)
	|| die $ora_errstr;

$nfields = &ora_fetch($csr);
print "Query will return $nfields fields\n\n";

while (($name, $phone) = &ora_fetch($csr))
{
	# mark any NULL fields found
	grep(defined || ($_ = '<NULL>'), $name, $phone);
	write;
}

do ora_close($csr) || die "can't close cursor";
do ora_logoff($lda) || die "can't log off Oracle";
