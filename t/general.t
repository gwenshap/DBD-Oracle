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

my($csr, $p1, $p2);

# --- test named numeric in/out parameters
#$dbh->trace(2);
my $sql = q{
	declare foo char(500);
    begin
    foo := :p1;
    foo := :p2;
    foo := :p3;
    foo := :p4;
    end;
};
ok(0, $csr = $dbh->prepare($sql), 1);

foreach (1..3) {
	ok(0, $dbh->do($sql, undef, 7,8,9,1), 1);
#	ok(0, $csr->execute(7,8,9,1), 1);
}


    # To do
    #   test NULLs at first bind
    #   NULLs later binds.
    #   returning NULLs
    #   multiple params, mixed types and in only vs inout

ok(0,  $dbh->ping);
$dbh->disconnect;
ok(0, !$dbh->ping);

exit 0;
BEGIN { $tests = 6 }
# end.

__END__
