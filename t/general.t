#!/usr/local/bin/perl -w

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
	if (!$ok && $warn) {
		$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
		warn "$warn\n";
	}
}

use DBI;
$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('', $dbuser, '', 'Oracle');

unless($dbh) {
	warn "Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n";
	print "1..0\n";
	exit 0;
}

print "1..$tests\n";

my($sth, $p1, $p2);

$sth = $dbh->prepare("select * from user_tables");
ok(0, $sth->{NUM_OF_FIELDS});
eval { $p1=$sth->{NUM_OFFIELDS_typo} };
ok(0, $@ =~ /attribute/);

    # To do
    #   test NULLs at first bind
    #   NULLs later binds.
    #   returning NULLs
    #   multiple params, mixed types and in only vs inout

ok(0,  $dbh->ping);
$dbh->disconnect;
ok(0, !$dbh->ping);

exit 0;
BEGIN { $tests = 4 }
# end.

__END__
