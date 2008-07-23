#!perl
use strict;
use warnings;

use DBI;
use Test::More;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

my $testcount = 9;
plan tests => $testcount;

$| = 1;

diag('test nls_date_format, ora_can_unicode');
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

SKIP :
{
    my $dbh = DBI->connect($dsn, $dbuser, '',
			   {
			    AutoCommit => 1,
			    PrintError => 1,
			   });

    skip "Unable to connect to Oracle ($DBI::errstr)", $testcount
      unless ($dbh);

    my ($nls_parameters_before, $nls_parameters_after);
    my $old_date_format = 'HH24:MI:SS DD/MM/YYYY';
    my $new_date_format = 'YYYYMMDDHH24MISS';

    ok($dbh->do("alter session set nls_date_format='$old_date_format'"), 'set date format');

    like($dbh->ora_can_unicode, qr/^[0123]/,                          'ora_can_unicode');

    ok($nls_parameters_before = $dbh->ora_nls_parameters,             'fetch ora_nls_parameters');
    is(ref($nls_parameters_before), 'HASH',                           'check ora_nls_parameters returned hashref');
    is($nls_parameters_before->{'NLS_DATE_FORMAT'}, $old_date_format, 'check returned nls_date_format');

    ok($dbh->do("alter session set nls_date_format='$new_date_format'"), 'alter date format');
    ok(eq_hash($nls_parameters_before, $dbh->ora_nls_parameters),        'check ora_nls_parameters caches old values');

    $nls_parameters_before->{NLS_DATE_FORMAT} = 'foo';
    isnt($nls_parameters_before->{NLS_DATE_FORMAT},
	$dbh->ora_nls_parameters->{NLS_DATE_FORMAT},        'check ora_nls_parameters returns a copy');

    is($dbh->ora_nls_parameters(1)->{'NLS_DATE_FORMAT'}, $new_date_format, 'refetch and check new nls_date_format value');
}

__END__
