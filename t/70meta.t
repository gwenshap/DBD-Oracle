#!perl -w
use Test::More;

use strict;
use DBI qw(:sql_types);
use Data::Dumper;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '', { PrintError => 0 });

if ($dbh) {
    plan tests=>13;
} else {
    plan skip_all => "Unable to connect to Oracle";
}

note("type_info_all\n");
my @types = $dbh->type_info(SQL_ALL_TYPES);
ok(@types >= 8, 'more than 8 types');
note(Dumper( @types ));

note("tables():\n");
my @tables = $dbh->tables;
note(@tables." tables\n");
ok(scalar @tables, 'tables');

my @table_info_params = (
	[ 'schema list',	undef, '%', undef, undef ],
	[ 'type list',   	undef, undef, undef, '%' ],
	[ 'table list',   	undef, undef, undef, undef ],
);
foreach my $table_info_params (@table_info_params) {
    my ($name) = shift @$table_info_params;
    my $start = time;
    diag("$name: table_info(".DBI::neat_list($table_info_params).")\n");
    my $table_info_sth = $dbh->table_info(@$table_info_params);
    ok($table_info_sth, 'table_info');
    my $data = $table_info_sth->fetchall_arrayref;
    ok($data, 'table_info fetch');
    ok(scalar @$data, 'table_info data returned');
    my $dur = time - $start;
    diag("$name: ".@$data." rows, $dur seconds\n");
#   print Dumper($data);
}

my $sql_dbms_version = $dbh->get_info(18);
ok($sql_dbms_version, 'dbms_version');
diag("sql_dbms_version=$sql_dbms_version\n");
like($sql_dbms_version, qr/^\d+\.\d+\.\d+$/, 'matched');

$dbh->disconnect;

exit 0;

