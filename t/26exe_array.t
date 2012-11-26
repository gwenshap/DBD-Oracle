# $Id$
# Completely new test for DBD::Oracle which came from DBD::ODBC
# Author: Martin J. Evans
#
# loads of execute_array and execute_for_fetch tests using DBI's methods
#
use Test::More;
use strict;
use Data::Dumper;
require 'nchar_test_lib.pl';

use lib 't/lib', 't';

$| = 1;

my $has_test_nowarnings = 1;
eval "require Test::NoWarnings";
$has_test_nowarnings = undef if $@;

my ($dbh, $ea);

use DBI qw(:sql_types);
use ExecuteArray;

END {
    if ($dbh && $ea) {
        $ea->drop_table($dbh);
        $dbh->disconnect();
    }
    Test::NoWarnings::had_no_warnings()
          if ($has_test_nowarnings);
    done_testing();
}

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
$ENV{NLS_NCHAR} = "US7ASCII";
$ENV{NLS_LANG} = "AMERICAN";

eval {
    $dbh = DBI->connect($dsn, $dbuser, '', {PrintError => 0});
};

if (!$dbh) {
    plan skip_all => "Unable to connect to Oracle";
}

$ea = ExecuteArray->new($dbh, 1); # set odbc_disable_array_operations
$dbh = $ea->dbh;

$ea->drop_table($dbh);
ok($ea->create_table($dbh), "create test table") or exit 1;
$ea->simple($dbh, {array_context => 1, raise => 1});
$ea->simple($dbh, {array_context => 0, raise => 1});
$ea->error($dbh, {array_context => 1, raise => 1});
$ea->error($dbh, {array_context => 0, raise => 1});
$ea->error($dbh, {array_context => 1, raise => 0});
$ea->error($dbh, {array_context => 0, raise => 0});

$ea->row_wise($dbh, {array_context => 1, raise => 1});

$ea->update($dbh, {array_context => 1, raise => 1});

$ea->error($dbh, {array_context => 1, raise => 1, notuplestatus => 1});
$ea->error($dbh, {array_context => 0, raise => 1, notuplestatus => 1});
$ea->error($dbh, {array_context => 1, raise => 0, notuplestatus => 1});
$ea->error($dbh, {array_context => 0, raise => 0, notuplestatus => 1});
