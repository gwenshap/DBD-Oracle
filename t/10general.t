#!perl -w

use Test::More;

use DBI;
use Oraperl;
use Config;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

plan tests => 33;

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '');

unless($dbh) {
	BAILOUT("Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n");
	exit 0;
}

my($sth, $p1, $p2, $tmp);

SKIP: {
	skip "not unix-like", 2 unless $Config{d_semctl};
	# basic check that we can fork subprocesses and wait for the status
	# after having connected to Oracle
	is system("exit 1;"), 1<<8, 'system exit 1 should return 256';
	is system("exit 0;"),    0, 'system exit 0 should return 0';
}


$sth = $dbh->prepare(q{
	/* also test preparse doesn't get confused by ? :1 */
        /* also test placeholder binding is case insensitive */
	select :a, :A from user_tables -- ? :1
});
ok($sth->{ParamValues});
is(keys %{$sth->{ParamValues}}, 1);
is($sth->{NUM_OF_PARAMS}, 1);
ok($sth->bind_param(':a', 'a value'));
ok($sth->execute);
ok($sth->{NUM_OF_FIELDS});
eval {
  local $SIG{__WARN__} = sub { die @_ }; # since DBI 1.43
  $p1=$sth->{NUM_OFFIELDS_typo};
};
ok($@ =~ /attribute/);
ok($sth->{Active});
ok($sth->finish);
ok(!$sth->{Active});

$sth = $dbh->prepare("select * from user_tables");
ok($sth->execute);
ok($sth->{Active});
1 while ($sth->fetch);	# fetch through to end
ok(!$sth->{Active});

# so following test works with other NLS settings/locations
ok($dbh->do("ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'"));

ok($tmp = $dbh->selectall_arrayref(q{
	select 1 * power(10,-130) "smallest?",
	       9.9999999999 * power(10,125) "biggest?"
	from dual
}));
my @tmp = @{$tmp->[0]};
#warn "@tmp"; $tmp[0]+=0; $tmp[1]+=0; warn "@tmp";
ok($tmp[0] <= 1.0000000000000000000000000000000001e-130, "tmp0=$tmp[0]");
ok($tmp[1] >= 9.99e+125, "tmp1=$tmp[1]");


my $warn='';
eval {
	local $SIG{__WARN__} = sub { $warn = $_[0] };
	$dbh->{RaiseError} = 1;
	$dbh->do("some invalid sql statement");
};
ok($@    =~ /DBD::Oracle::db do failed:/, "eval error: ``$@'' expected 'do failed:'");
#print "''$warn''";
ok($warn =~ /DBD::Oracle::db do failed:/, "warn error: ``$warn'' expected 'do failed:'");
ok($DBI::err);
ok($ora_errno);
is($ora_errno, $DBI::err);
$dbh->{RaiseError} = 0;

# ---

ok( $dbh->ping);
ok(!$ora_errno);	# ora_errno reset ok
ok(!$DBI::err);	# DBI::err  reset ok

$dbh->disconnect;
$dbh->{PrintError} = 0;
ok(!$dbh->ping);

my $ora_oci = DBD::Oracle::ORA_OCI(); # dualvar
printf "ORA_OCI = %d (%s)\n", $ora_oci, $ora_oci;
ok("$ora_oci");
ok($ora_oci >= 8);
my @ora_oci = split(/\./, $ora_oci,-1);
ok(scalar @ora_oci >= 2);
ok(scalar @ora_oci == grep { DBI::looks_like_number($_) } @ora_oci);
is($ora_oci[0], int($ora_oci));

exit 0;
