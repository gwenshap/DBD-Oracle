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
$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbuser_2 = $ENV{ORACLE_USERID_2} || '';

sub give_up { warn @_ if @_; print "1..0\n"; exit 0; }

if ($dbuser_2 eq '') {
    print("ORACLE_USERID_2 not defined.\nTests skiped.\n");
    give_up();
}
(my $uid1 = uc $dbuser) =~ s:/.*::;
(my $uid2 = uc $dbuser_2) =~ s:/.*::;
if ($uid1 eq $uid2) {
    give_up("ORACLE_USERID_2 not unique.\nTests skiped.\n")
}

my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '');

unless($dbh) {
    give_up("Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n");
}

print "1..3\n";

ok(0, ($dbh->selectrow_array("SELECT USER FROM DUAL"))[0] eq $uid1 );
ok(0, $dbh->func($dbuser_2, '', 'reauthenticate'));
ok(0, ($dbh->selectrow_array("SELECT USER FROM DUAL"))[0] eq $uid2 );

$dbh->disconnect;
