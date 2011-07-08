#!perl -w

use DBI;
use DBD::Oracle(qw(:ora_fail_over));
use strict;
use Data::Dumper;

use Test::More;
unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;


# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh;
eval {$dbh = DBI->connect($dsn, $dbuser, '',)};
if ($dbh) {
    if ($dbh->ora_can_taf()){
      plan tests => 1;  
    }
    else {
       plan tests =>1;      
    }
} else {
    plan skip_all => "Unable to connect to Oracle";
}

$dbh->disconnect;

if (!$dbh->ora_can_taf()){
    
  eval {$dbh = DBI->connect($dsn, $dbuser, '',{ora_taf=>1,taf_sleep=>15,ora_taf_function=>'taf'})};   
  ok($@    =~ /You are attempting to enable TAF/, "'$@' expected! ");      
  
    
}
else {
   ok($dbh = DBI->connect($dsn, $dbuser, '',{ora_taf=>1,taf_sleep=>15,ora_taf_function=>'taf'}),"Well this is all I can test!");         
    
}

$dbh->disconnect;
#not much I can do with taf as I cannot really shut down somones server pephaps later

1;
