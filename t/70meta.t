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
use DBI qw(:sql_types);
use Data::Dumper;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '', { PrintError => 0 });

unless ($dbh) {
	warn "Unable to connect to Oracle as $dbuser ($DBI::errstr)\nTests skipped.\n";
	print "1..0\n";
	exit 0;
}

print "1..13\n";

print "type_info_all\n";
my @types = $dbh->type_info(SQL_ALL_TYPES);
ok(0, @types >= 8);
print Dumper( @types );

print "tables():\n";
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

my $sql_dbms_version = $dbh->get_info(18);
ok(0,$sql_dbms_version);
print "sql_dbms_version=$sql_dbms_version\n";
ok(0,$sql_dbms_version =~ /^\d+\.\d+\.\d+$/);

$dbh->disconnect;

exit 0;

