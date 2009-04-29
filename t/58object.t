#!perl -w

use DBI;
use DBD::Oracle qw(ORA_RSET SQLCS_NCHAR);
use strict;
use Data::Dumper;

use Test::More tests => 34;
unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

BEGIN {
	use_ok('DBI');
}

$ENV{NLS_DATE_FORMAT} = 'YYYY-MM-DD"T"HH24:MI:SS';

# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '',{ RaiseError=>1, 
					AutoCommit=>1,
					PrintError => 0,
					 ora_objects => 1 });

my ($schema) = $dbuser =~ m{^([^/]*)};

# Test ora_objects flag 
cmp_ok($dbh->{ora_objects}, 'eq', '1', 'ora_objects flag is set to 1');

$dbh->{ora_objects} = 0;
cmp_ok($dbh->{ora_objects}, 'eq', '0', 'ora_objects flag is set to 0');

# check that our db handle is good
isa_ok($dbh, "DBI::db");

my $obj_prefix = "dbd_test_";
my $super_type = "${obj_prefix}_type_A";
my $sub_type = "${obj_prefix}_type_B";
my $table = "${obj_prefix}_obj_table";

sub drop_test_objects {
    for my $obj ("TABLE $table", "TYPE $sub_type", "TYPE $super_type") {
        #do not warn if already there
        eval {
            local $dbh->{PrintError} = 0;
            $dbh->do(qq{drop $obj});
        };
    }
}

&drop_test_objects;

$dbh->do(qq{ CREATE OR REPLACE TYPE $super_type AS OBJECT (
                num     INTEGER,
                name    VARCHAR2(20)
            ) NOT FINAL }) or die $dbh->errstr;

$dbh->do(qq{ CREATE OR REPLACE TYPE $sub_type UNDER $super_type (
                datetime  DATE,
                amount    NUMERIC(10,5)
            ) NOT FINAL }) or die $dbh->errstr;
$dbh->do(qq{ CREATE TABLE $table (id INTEGER, obj $super_type) })
            or die $dbh->errstr;
$dbh->do(qq{ INSERT INTO $table VALUES (1, $super_type(13, 'obj1')) })
            or die $dbh->errstr;
$dbh->do(qq{ INSERT INTO $table VALUES (2, $sub_type(NULL, 'obj2', 
                    TO_DATE('2004-11-30 14:27:18', 'YYYY-MM-DD HH24:MI:SS'),
                    12345.6789)) }
            ) or die $dbh->errstr;
$dbh->do(qq{ INSERT INTO $table VALUES (3, $sub_type(5, 'obj3', NULL, 777.666)) }
            ) or die $dbh->errstr;

# Test old (backward compatible) interface 

# test select testing objects 
my $sth = $dbh->prepare("select * from $table order by id");
ok ($sth, 'old: Prepare select');
ok ($sth->execute(), 'old: Execute select');

my @row1 = $sth->fetchrow();
ok (scalar @row1, 'old: Fetch first row');
cmp_ok(ref $row1[1], 'eq', 'ARRAY', 'old: Row 1 column 2 is an ARRAY');
cmp_ok(scalar(@{$row1[1]}), '==', 2, 'old: Row 1 column 2 is has 2 elements');

my @row2 = $sth->fetchrow();
ok (scalar @row2, 'old: Fetch second row');
cmp_ok(ref $row2[1], 'eq', 'ARRAY', 'old: Row 2 column 2 is an ARRAY');
cmp_ok(scalar(@{$row2[1]}), '==', 2, 'old: Row 2 column 2 is has 2 elements');

my @row3 = $sth->fetchrow();
ok (scalar @row3, 'old: Fetch third row');
cmp_ok(ref $row3[1], 'eq', 'ARRAY', 'old: Row 3 column 2 is an ARRAY');
cmp_ok(scalar(@{$row3[1]}), '==', 2, 'old: Row 3 column 2 is has 2 elements');

ok (!$sth->fetchrow(), 'old: No more rows expected');

#print STDERR Dumper(\@row1, \@row2, \@row3);

# Test new (extended) object interface 

# enable extended object support 
$dbh->{ora_objects} = 1;

# test select testing objects - in extended mode 
$sth = $dbh->prepare("select * from $table order by id");
ok ($sth, 'new: Prepare select');
ok ($sth->execute(), 'new: Execute select');


@row1 = $sth->fetchrow();
ok (scalar @row1, 'new: Fetch first row');
cmp_ok(ref $row1[1], 'eq', 'DBD::Oracle::Object', 'new: Row 1 column 2 is an DBD:Oracle::Object');
cmp_ok(uc $row1[1]->type_name, "eq", uc "$schema.$super_type", "new: Row 1 column 2 object type");
is_deeply([$row1[1]->attributes], ['NUM', 13, 'NAME', 'obj1'], "new: Row 1 column 2 object attributes");

@row2 = $sth->fetchrow();
ok (scalar @row2, 'new: Fetch second row');
cmp_ok(ref $row2[1], 'eq', 'DBD::Oracle::Object', 'new: Row 2 column 2 is an DBD::Oracle::Object');
cmp_ok(uc $row2[1]->type_name, "eq", uc "$schema.$sub_type", "new: Row 2 column 2 object type");
is_deeply([$row2[1]->attributes], ['NUM', undef, 'NAME', 'obj2', 
            'DATETIME', '2004-11-30T14:27:18', 'AMOUNT', '12345.6789'], "new: Row 1 column 2 object attributes");

@row3 = $sth->fetchrow();
ok (scalar @row3, 'new: Fetch third row');
cmp_ok(ref $row3[1], 'eq', 'DBD::Oracle::Object', 'new: Row 3 column 2 is an DBD::Oracle::Object');
cmp_ok(uc $row3[1]->type_name, "eq", uc "$schema.$sub_type", "new: Row 3 column 2 object type");
is_deeply([$row3[1]->attributes], ['NUM', 5, 'NAME', 'obj3', 
            'DATETIME', undef, 'AMOUNT', '777.666'], "new: Row 1 column 2 object attributes");

ok (!$sth->fetchrow(), 'new: No more rows expected');

#print STDERR Dumper(\@row1, \@row2, \@row3);

# Test DBD::Oracle::Object 
my $obj = $row3[1];
my $expected_hash = {
        NUM         => 5,
        NAME        => 'obj3',
        DATETIME    => undef,
        AMOUNT      => 777.666,
    };
is_deeply($obj->attr_hash, $expected_hash, 'DBD::Oracle::Object->attr_hash');
is_deeply($obj->attr, $expected_hash, 'DBD::Oracle::Object->attr');
is($obj->attr("NAME"), 'obj3', 'DBD::Oracle::Object->attr("NAME")');

#cleanup 
&drop_test_objects;
$dbh->disconnect;

1;
