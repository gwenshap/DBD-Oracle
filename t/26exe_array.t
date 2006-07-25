#!perl -w

use DBI;
use DBD::Oracle qw(ORA_RSET SQLCS_NCHAR);
use strict;

use Test::More tests =>13 ;
unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

## ----------------------------------------------------------------------------
## 26exe_array.t
## By John Scoles, The Pythian Group
## ----------------------------------------------------------------------------
##  Just a few checks to see if execute array works in Oracle::DBD
##  Nothing fancy. 
## ----------------------------------------------------------------------------

BEGIN {
	use_ok('DBI');
}

# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '', { RaiseError=>1, 
						AutoCommit=>1,
						PrintError => 0 });


# check that our db handle is good
isa_ok($dbh, "DBI::db");

my $table = table();
    
$dbh->do(qq{
            CREATE TABLE $table (
	    row_1 INTEGER NOT NULL,
	    row_2 INTEGER NOT NULL,
	    row_3 INTEGER NOT NULL
	)
    });
    
my $rv;
my @var1         = (1,1,1,1,1,1,1,1,1,1);
my @var2         = (2,2,2,2,2,2,2,2,2,2);
my @var3         = (3,3,3,3,3,3,3,3,3,3);

my $tuple_status = [];
my $dumped ;


my $rows = [];

# simple bind and execute_arry

my $sth = $dbh->prepare("INSERT INTO $table ( row_1,  row_2, row_3) VALUES (?,?,?)");


ok ($sth->execute_array(
      {ArrayTupleStatus => $tuple_status},
        \@var1,
        \@var2,
       \@var2,
 ), '... execute_array should return true');


cmp_ok(scalar @{$tuple_status}, '==', 10, '... we should have 10 tuple_status');


# simple check to ensurte the error is returned in the status tuple

@var2         = (2,2,2,2,'s',2,2,2,2,2);

ok (!$sth->execute_array(
      {ArrayTupleStatus => $tuple_status},
        \@var1,
        \@var2,
       \@var2,
 ), '... execute_array should return flase');

  cmp_ok(scalar @{$tuple_status}, '==', 10, '... we should have 10 tuple_status');

  cmp_ok( $tuple_status->[4]->[1],'ne','-1','... we should get text');

  cmp_ok( $tuple_status->[3],'==',-1,'... we should get -1');


# siple test with execute_for_fetch
# need some datat
 my $sth2 = $dbh->prepare("select row_1,  row_2, row_3 from  $table");

 $sth2->execute();

 my $problems = $sth2->fetchall_arrayref();


$sth = $dbh->prepare("INSERT INTO  $table ( row_1,  row_2, row_3) VALUES (?,?,?)");

 ok($sth->execute_for_fetch( sub { shift @$problems },$tuple_status), '... execute_for_fetch should return true');

  cmp_ok(scalar @{$tuple_status}, '==',19 , '... we should have 19 tuple_status');


#simple test for array bind param 

 @var2         = (2,2,2,2,2,2,2,2,2,2);

 $sth = $dbh->prepare("INSERT INTO $table ( row_1,  row_2, row_3) VALUES (?,?,?)");

 $sth->bind_param_array(1,\@var1);
 $sth->bind_param_array(2,\@var2);
 $sth->bind_param_array(3,\@var3);

ok( $sth->execute_array( { ArrayTupleStatus => $tuple_status } ), '... execute_array should return flase');

   cmp_ok(scalar @{$tuple_status}, '==',10, '... we should have 10 tuple_status');

#last check to see it the number add up

$sth2 = $dbh->prepare("select * from $table");

$sth2->execute();

  $problems = $sth2->fetchall_arrayref();


 cmp_ok(scalar @$problems, '==',48, '... we should have 48 rows');


 drop_table($dbh);


$dbh->disconnect;

1;

