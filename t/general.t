#!perl -w

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n"
	  : print "# failed test $t at line ".(caller)[2]."\nnot ok $t\n";
	if (!$ok && $warn) {
		$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
		warn "$warn\n";
	}
}

use DBI;
use Oraperl;
$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '');

unless($dbh) {
	warn "Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n";
	print "1..0\n";
	exit 0;
}

print "1..$tests\n";

my($sth, $p1, $p2, $tmp);

$sth = $dbh->prepare(q{
	/* also test preparse doesn't get confused by ? :1 */
	select * from user_tables -- ? :1
});
ok(0, $sth->{ParamValues});
ok(0, keys %{$sth->{ParamValues}} == 0);
ok(0, $sth->execute);
ok(0, $sth->{NUM_OF_FIELDS});
eval { $p1=$sth->{NUM_OFFIELDS_typo} };
ok(0, $@ =~ /attribute/);
ok(0, $sth->{Active});
ok(0, $sth->finish);
ok(0, !$sth->{Active});

$sth = $dbh->prepare("select * from user_tables");
ok(0, $sth->execute);
ok(0, $sth->{Active});
1 while ($sth->fetch);	# fetch through to end
ok(0, !$sth->{Active});

# so following test works with other NLS settings/locations
ok(0, $dbh->do("ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'"), 1);

ok(0, $tmp = $dbh->selectall_arrayref(q{
	select 1 * power(10,-130) "smallest?",
	       9.9999999999 * power(10,125) "biggest?"
	from dual
}));
my @tmp = @{$tmp->[0]};
#warn "@tmp"; $tmp[0]+=0; $tmp[1]+=0; warn "@tmp";
ok(0, $tmp[0] <= 1.0000000000000000000000000000000001e-130, $tmp[0]);
ok(0, $tmp[1] >= 9.99e+125, $tmp[1]);


my $warn='';
eval {
	$SIG{__WARN__} = sub { $warn = $_[0] };
	$dbh->{RaiseError} = 1;
	$dbh->do("some invalid sql statement");
};
ok(0, $@    =~ /DBD::Oracle::db do failed:/, "eval error: ``$@'' expected 'do failed:'");
#print "''$warn''";
ok(0, $warn =~ /DBD::Oracle::db do failed:/, "warn error: ``$warn'' expected 'do failed:'");
ok(0, $DBI::err);
ok(0, $ora_errno);
ok(0, $ora_errno == $DBI::err);
$dbh->{RaiseError} = 0;

# ---

ok(0,  $dbh->ping);
ok(0, !$ora_errno);	# ora_errno reset ok
ok(0, !$DBI::err);	# DBI::err  reset ok

$dbh->disconnect;
$dbh->{PrintError} = 0;
ok(0, !$dbh->ping);

exit 0;
BEGIN { $tests = 24 }
# end.

__END__
