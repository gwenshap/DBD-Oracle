#!perl -w
# From: Jeffrey Horn <horn@cs.wisc.edu>

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
use DBD::Oracle qw(ORA_RSET);
use strict;

$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', { PrintError => 0 });

unless ($dbh) {
	warn "Unable to connect to Oracle as $dbuser ($DBI::errstr)\nTests skipped.\n";
	print "1..0\n";
	exit 0;
}

# ORA-00900: invalid SQL statement
# ORA-06553: PLS-213: package STANDARD not accessible
my $tst = $dbh->prepare(q{declare foo char(50); begin RAISE INVALID_NUMBER; end;});
if ($dbh->err && ($dbh->err==900 || $dbh->err==6553 || $dbh->err==600)) {
	warn "Your Oracle server doesn't support PL/SQL"	if $dbh->err== 900;
	warn "Your Oracle PL/SQL is not properly installed"	if $dbh->err==6553||$dbh->err==600;
	warn "Tests skipped\n";
	print "1..0\n";
	exit 0;
}

my $limit = $dbh->selectrow_array(q{
	SELECT value-2 FROM v$parameter WHERE name = 'open_cursors'
});
$limit -= 2 if $limit && $limit >= 2; # allow for our open and close cursor 'cursors'
unless (defined $limit) { # v$parameter open_cursors could be 0 :)
	print "Can't determine open_cursors from v\$parameter, so using default\n";
	$limit = 1;
}
print "Max cursors: $limit\n";
$limit = 100 if $limit > 100; # lets not be greedy or upset DBA's

my $tests = 2 + 10 * $limit;

print "1..$tests\n";


my @cursors;
my @row;

print "opening cursors\n";
my $open_cursor = $dbh->prepare( qq{
	BEGIN OPEN :kursor FOR
		SELECT * FROM all_objects WHERE rownum < 5;
	END;
} );
ok( 0, $open_cursor );

foreach ( 1 .. $limit ) {
	print "opening cursor $_\n";
	ok( 0, $open_cursor->bind_param_inout( ":kursor", \my $cursor, 0, { ora_type => ORA_RSET } ) );
	ok( 0, $open_cursor->execute );
	ok( 0, !$open_cursor->{Active} );

	ok( 0, $cursor->{Active} );
	ok( 0, $cursor->fetchrow_arrayref);
	ok( 0, $cursor->fetchrow_arrayref);
	ok( 0, $cursor->finish );	# finish early
	ok( 0, !$cursor->{Active} );

	push @cursors, $cursor;
}

if (DBD::Oracle::ORA_OCI() == 8 ) {
	print "closing cursors\n";
	my $close_cursor = $dbh->prepare( qq{ BEGIN CLOSE :kursor; END; } );
	ok(0, $close_cursor);
	foreach ( 1 .. @cursors ) {
		print "closing cursor $_\n";
		my $cursor = $cursors[$_-1];
		ok(0, $close_cursor->bind_param( ":kursor", $cursor, { ora_type => ORA_RSET }));
		ok(0, $close_cursor->execute);
	}
}
else {
	warn " explicit cursor closing skipped due to known DBD::Oracle bug with OCI7\n";
	ok(0,1);
	foreach ( 1 .. @cursors ) { ok(0,1); ok(0,1); }
}

$dbh->disconnect;

exit 0;

