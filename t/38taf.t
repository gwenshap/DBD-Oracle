#!perl -w
# $Id$

use DBI;
use DBD::Oracle(qw(:ora_fail_over));
use strict;
#use Devel::Peek qw(SvREFCNT Dump);

use Test::More;
unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;


# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

my $dbh = eval { DBI->connect($dsn, $dbuser, '',) }
    or plan skip_all => "Unable to connect to Oracle";

$dbh->disconnect;

if ( !$dbh->ora_can_taf ){

    eval {
        $dbh = DBI->connect(
            $dsn, $dbuser, '',
            {ora_taf=>1, ora_taf_sleep=>15,ora_taf_function=>'taf'})
    };
  ok($@    =~ /You are attempting to enable TAF/, "'$@' expected! ");


}
else {
   ok $dbh = DBI->connect($dsn, $dbuser, '',
                          {ora_taf=>1, ora_taf_sleep=>15,
                           ora_taf_function=>'taf'});

   is($dbh->{ora_taf}, 1, 'TAF enabled');
   is($dbh->{ora_taf_sleep}, 15, 'TAF sleep set');
   is($dbh->{ora_taf_function}, 'taf', 'TAF callback');

   $dbh->{ora_taf} = 0;
   is($dbh->{ora_taf}, 0, 'TAF disabled');

   $dbh->{ora_taf_sleep} = 10;
   is($dbh->{ora_taf_sleep}, 10, 'TAF sleep set');

   my $x = sub {};
#   diag(SvREFCNT($x));
#   diag(Dump($x));
   $dbh->{ora_taf_function} = $x;
   is(ref($dbh->{ora_taf_function}), 'CODE', 'TAF code ref');

#   diag(SvREFCNT($x));
}

$dbh->disconnect;

done_testing();
