#!/usr/bin/perl

use strict;
use Test::More tests => 2;
use DBD::Oracle qw(:ora_types);
use DBI;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

my $dbh;
$| = 1;
SKIP: {

    $dbh = db_handle();
    plan skip_all => "Not connected to oracle" if not $dbh;

    my $table = table();
    drop_table($dbh);
    
    $dbh->do(qq{
	CREATE TABLE $table (
	    id INTEGER NOT NULL,
	    data BLOB
	)
    });

my ($stmt, $sth, $id, $loc);
## test with insert empty blob and select locator.
$stmt = "INSERT INTO $table (id,data) VALUES (1, EMPTY_BLOB())";
$dbh->do($stmt);

$stmt = "SELECT data FROM $table WHERE id = ?";
$sth = $dbh->prepare($stmt, {ora_auto_lob => 0});
$id = 1;
$sth->bind_param(1, $id);
$sth->execute;
($loc) = $sth->fetchrow;
is (ref $loc, "OCILobLocatorPtr", "returned valid locator");

## test with insert empty blob returning blob to a var.
($id, $loc) = (2, undef);
$stmt = "INSERT INTO $table (id,data) VALUES (?, EMPTY_BLOB()) RETURNING data INTO ?";
$sth = $dbh->prepare($stmt, {ora_auto_lob => 0});
$sth->bind_param(1, $id);
$sth->bind_param_inout(2, \$loc, 0, {ora_type => ORA_BLOB});
$sth->execute;
is (ref $loc, "OCILobLocatorPtr", "returned valid locator");

$dbh->do("DROP TABLE $table");
$dbh->disconnect;

}

1;
