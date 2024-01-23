#!perl
$| = 1;

## ----------------------------------------------------------------------------
## 12imptdata.t
## By Jeffrey Klein,
## ----------------------------------------------------------------------------

use strict;
use warnings;

use lib 't/lib';
use DBDOracleTestLib qw/ oracle_test_dsn db_handle /;

use DBI;
use Config qw(%Config);

# must be done before Test::More - see Threads in Test::More pod
BEGIN { eval "use threads; use threads::shared;" }
my $use_threads_err = $@;
use Test::More;

BEGIN {
    if ( $DBI::VERSION <= 1.601 ) {
        plan skip_all => "DBI version "
          . $DBI::VERSION
          . " does not support iThreads. Use version 1.602 or later.";
    }
    die $use_threads_err if $use_threads_err;    # need threads
}

my $dbh    = db_handle( { PrintError => 0 } );

if ($dbh) {
    plan tests => 7;
}
else {
    plan skip_all => 'Unable to connect to Oracle';
}
my $drh = $dbh->{Driver};
my ($sess_1) = $dbh->selectrow_array(q/select userenv('sessionid') from dual/);

is $drh->{Kids},       1, '1 kid';
is $drh->{ActiveKids}, 1, '1 active kid';

my $imp_data = $dbh->take_imp_data;
is $drh->{Kids},       0, 'no kids';
is $drh->{ActiveKids}, 0, 'no active kids';

$dbh = db_handle( { dbi_imp_data => $imp_data } );
my ($sess_2) = $dbh->selectrow_array(q/select userenv('sessionid') from dual/);
is $sess_1, $sess_2, 'got same session';

is $drh->{Kids},       1, '1 kid';
is $drh->{ActiveKids}, 1, '1 active kid';

__END__
