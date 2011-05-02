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

use strict;
use DBI;
use Data::Dumper;

$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', { PrintError => 0 });

unless ($dbh) {
	warn "Unable to connect to Oracle as $dbuser ($DBI::errstr)\nTests skipped.\n";
	print "1..0\n";
	exit 0;
}

print "1..10\n";

my @tables = $dbh->tables;
print @tables." tables\n";
ok(0, scalar @tables);

my @table_info_params = (
	[ 'schema list',	undef, '%', undef, undef ],
	[ 'type list',   	undef, undef, undef, '%' ],
	[ 'table list',   	undef, undef, undef, undef ],
);
foreach my $table_info_params (@table_info_params) {
    my ($name) = shift @$table_info_params;
    my $start = time;
    print "$name: table_info(".DBI::neat_list($table_info_params).")\n";
    my $table_info_sth = $dbh->table_info(@$table_info_params);
    ok(0, $table_info_sth);
    my $data = $table_info_sth->fetchall_arrayref;
    ok(0, $data);
    ok(0, scalar @$data);
    my $dur = time - $start;
    print "$name: ".@$data." rows, $dur seconds\n";
#   print Dumper($data);
}

$dbh->disconnect;

exit 0;

