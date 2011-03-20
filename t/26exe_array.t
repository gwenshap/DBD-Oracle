#!/usr/bin/perl -w -I./t

## ----------------------------------------------------------------------------
## 26exe_array.t this is a completly new one 
## By Martin J. Evans orgianlly called 70execute_array.t for the ODBC DBD driver
## and adatped into DBD::Oracle (in a very minor way) by John Scoles, The Pythian Group
## ----------------------------------------------------------------------------
## loads of execute_array and execute_for_fetch tests
## tests both insert and update and row fetching
## with RaiseError on and off and AutoCommit on and off
## ----------------------------------------------------------------------------

use Test::More;
use strict;
use Data::Dumper;
require 'nchar_test_lib.pl';

$| = 1;


my $table = 'PERL_DBD_execute_array';
my $table2 = 'PERL_DBD_execute_array2';
my @captured_error;                  # values captured in error handler


# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
$ENV{NLS_NCHAR} = "US7ASCII";
$ENV{NLS_LANG} = "AMERICAN";

my $dbh;
my @p1 = (1,2,3,4,5);
my @p2 = qw(one two three four five);
my $fetch_row = 0;

use DBI qw(:sql_types);

eval {
    $dbh = DBI->connect($dsn, $dbuser, '', {PrintError => 0});
};

if (!$dbh) {
    plan skip_all => "Unable to connect to Oracle";
}
else {
    plan tests=>406;
}


#$dbh->{PrintError} = 1;
my $has_test_nowarnings = 1;
eval "require Test::NoWarnings";
$has_test_nowarnings = undef if $@;
use_ok('Data::Dumper');

END {
    if ($dbh) {
        drop_table_local($dbh);
    }
    Test::NoWarnings::had_no_warnings()
          if ($has_test_nowarnings);
}

sub error_handler
{
    @captured_error = @_;
    diag("***** error handler called *****");
    0;                          # pass errors on
}

sub create_table_local
{
    my $dbh = shift;

    eval {
        $dbh->do(qq/create table $table (a int primary key, b char(20))/);
    };
    if ($@) {
        diag("Failed to create test table $table - $@");
        return 0;
    }
    eval {
        $dbh->do(qq/create table $table2 (a int primary key, b char(20))/);
    };
    if ($@) {
        diag("Failed to create test table $table2 - $@");
        return 0;
    }
    my $sth = $dbh->prepare(qq/insert into $table2 values(?,?)/);
    for (my $row = 0; $row < @p1; $row++) {
        $sth->execute($p1[$row], $p2[$row]);
    }
    1;
}

sub drop_table_local
{
    my $dbh = shift;

    eval {
        local $dbh->{PrintError} = 0;
        local $dbh->{PrintWarn} = 0;
        $dbh->do(qq/drop table $table/);
        $dbh->do(qq/drop table $table2/);
    };
    diag("Table dropped");
}

# clear the named table of rows
sub clear_table
{
    $_[0]->do(qq/delete from $_[1]/);
}

# check $table contains the data in $c1, $c2 which are arrayrefs of values
sub check_data
{
    my ($dbh, $c1, $c2) = @_;

    my $data = $dbh->selectall_arrayref(qq/select * from $table order by a/);
    my $row = 0;
    foreach (@$data) {
        is($_->[0], $c1->[$row], "row $row p1 data");
        is($_->[1], $c2->[$row], "row $row p2 data");
        $row++;
    }
}

sub check_tuple_status
{
    my ($tsts, $expected) = @_;

    diag(Data::Dumper->Dump([$tsts], [qw(ArrayTupleStatus)]));
    my $row = 0;
    foreach my $s (@$tsts) {
        if (ref($expected->[$row])) {
            is(ref($s), 'ARRAY', 'array in array tuple status');
            is(scalar(@$s), 3, '3 elements in array tuple status error');
        } else {
            if ($s == -1) {
                pass("row $row tuple status unknown");
            } else {
                is($s, $expected->[$row], "row $row tuple status");
            }
        }
        $row++
    }
}

# insert might return 'mas' which means the caller said the test
# required Multiple Active Statements and the driver appeared to not
# support MAS.
sub insert
{
    my ($dbh, $sth, $ref) = @_;

    die "need hashref arg" if (!$ref || (ref($ref) ne 'HASH'));
    diag("insert " . join(", ", map {"$_ = ". DBI::neat($ref->{$_})} keys %$ref ));
    # DBD::Oracle supports MAS don't compensate for it not
    if ($ref->{requires_mas} && $dbh->{Driver}->{Name} eq 'Oracle') {
        delete $ref->{requires_mas};
    }
    @captured_error = ();

    if ($ref->{raise}) {
        $sth->{RaiseError} = 1;
    } else {
        $sth->{RaiseError} = 0;
    }

    my (@tuple_status, $sts, $total_affected);
    $sts = 999999;              # to ensure it is overwritten
    $total_affected = 999998;
    if ($ref->{array_context}) {
        eval {
            if ($ref->{params}) {
                ($sts, $total_affected) =
                    $sth->execute_array({ArrayTupleStatus => \@tuple_status},
                                        @{$ref->{params}});
            } elsif ($ref->{fetch}) {
                ($sts, $total_affected) =
                    $sth->execute_array(
                        {ArrayTupleStatus => \@tuple_status,
                         ArrayTupleFetch => $ref->{fetch}});
            } else {
                ($sts, $total_affected) =
                    $sth->execute_array({ArrayTupleStatus => \@tuple_status});
            }
        };
    } else {
        eval {
            if ($ref->{params}) {
                $sts =
                    $sth->execute_array({ArrayTupleStatus => \@tuple_status},
                                        @{$ref->{params}});
            } else {
                $sts =
                    $sth->execute_array({ArrayTupleStatus => \@tuple_status});
            }
        };
    }
    if ($ref->{error} && $ref->{raise}) {
        ok($@, 'error in execute_array eval');
    } else {
        if ($ref->{requires_mas} && $@) {
            diag("\nThis test died with $@");
            diag("It requires multiple active statement support in the driver and I cannot easily determine if your driver supports MAS. Ignoring the rest of this test.");
            foreach (@tuple_status) {
                if (ref($_)) {
                    diag(join(",", @$_));
                }
            }
            return 'mas';
        }
        ok(!$@, 'no error in execute_array eval') or diag($@);
    }
    $dbh->commit if $ref->{commit};

    if (!$ref->{raise} || ($ref->{error} == 0)) {
        if (exists($ref->{sts})) {
            is($sts, $ref->{sts},
               "execute_array returned " . DBI::neat($sts) . " rows executed");
        }
        if (exists($ref->{affected}) && $ref->{array_context}) {
            is($total_affected, $ref->{affected},
               "total affected " . DBI::neat($total_affected))
        }
    }
    if ($ref->{raise}) {
        if ($ref->{error}) {
            ok(scalar(@captured_error) > 0, "error captured");
        } else {
            is(scalar(@captured_error), 0, "no error captured");
        }
    }
    if ($ref->{sts}) {
        is(scalar(@tuple_status), (($ref->{sts} eq '0E0') ? 0 : $ref->{sts}),
           "$ref->{sts} rows in tuple_status");
    }
    if ($ref->{tuple}) {
        check_tuple_status(\@tuple_status, $ref->{tuple});
    }
    return;
}
# simple test on ensure execute_array with no errors:
# o checks returned status and affected is correct
# o checks ArrayTupleStatus is correct
# o checks no error is raised
# o checks rows are inserted
# o run twice with AutoCommit on/off
# o checks if less values are specified for one parameter the right number
#   of rows are still inserted and NULLs are placed in the missing rows
# checks binding via bind_param_array and adding params to execute_array
# checks binding no parameters at all
sub simple
{
    my ($dbh, $ref) = @_;

    diag('simple tests ' . join(", ", map {"$_ = $ref->{$_}"} keys %$ref ));

    diag("  all param arrays the same size");
    foreach my $commit (1,0) {
        diag("    Autocommit: $commit");
        clear_table($dbh, $table);
        $dbh->begin_work if !$commit;

        my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
        $sth->bind_param_array(1, \@p1);
        $sth->bind_param_array(2, \@p2);
        insert($dbh, $sth,
               { commit => !$commit, error => 0, sts => 5, affected => 5,
                 tuple => [1, 1, 1, 1, 1], %$ref});
        check_data($dbh, \@p1, \@p2);
    }

    diag ("  Not all param arrays the same size");
    clear_table($dbh, $table);
    my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);

    $sth->bind_param_array(1, \@p1);
    $sth->bind_param_array(2, [qw(one)]);
    insert($dbh, $sth, {commit => 0, error => 0,
                        raise => 1, sts => 5, affected => 5,
                        tuple => [1, 1, 1, 1, 1], %$ref});
    check_data($dbh, \@p1, ['one', undef, undef, undef, undef]);

    diag ("  Not all param arrays the same size with bind on execute_array");
    clear_table($dbh, $table);
    $sth = $dbh->prepare(qq/insert into $table values(?,?)/);

    insert($dbh, $sth, {commit => 0, error => 0,
                        raise => 1, sts => 5, affected => 5,
                        tuple => [1, 1, 1, 1, 1], %$ref,
                        params => [\@p1, [qw(one)]]});
    check_data($dbh, \@p1, ['one', undef, undef, undef, undef]);

    diag ("  no parameters");
    clear_table($dbh, $table);
    $sth = $dbh->prepare(qq/insert into $table values(?,?)/);

    insert($dbh, $sth, {commit => 0, error => 0,
                        raise => 1, sts => '0E0', affected => 0,
                        tuple => [], %$ref,
                        params => [[], []]});
    check_data($dbh, \@p1, ['one', undef, undef, undef, undef]);
}

# error test to ensure correct behavior for execute_array when it errors:
# o execute_array of 5 inserts with last one failing
#  o check it raises an error
#  o check caught error is passed on from handler for eval
#  o check returned status and affected rows
#  o check ArrayTupleStatus
#  o check valid inserts are inserted
#  o execute_array of 5 inserts with 2nd last one failing
#  o check it raises an error
#  o check caught error is passed on from handler for eval
#  o check returned status and affected rows
#  o check ArrayTupleStatus
#  o check valid inserts are inserted
sub error
{
    my ($dbh, $ref) = @_;

    die "need hashref arg" if (!$ref || (ref($ref) ne 'HASH'));

    diag('error tests ' . join(", ", map {"$_ = $ref->{$_}"} keys %$ref ));
    {
        diag("Last row in error");

        clear_table($dbh, $table);
        my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
        my @pe1 = @p1;
        $pe1[-1] = 1;
        $sth->bind_param_array(1, \@pe1);
        $sth->bind_param_array(2, \@p2);
        insert($dbh, $sth, {commit => 0, error => 1, sts => undef,
                            affected => undef, tuple => [1, 1, 1, 1, []],
                            %$ref});
        check_data($dbh, [@pe1[0..4]], [@p2[0..4]]);
    }

    {
        diag("2nd last row in error");
        clear_table($dbh, $table);
        my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
        my @pe1 = @p1;
        $pe1[-2] = 1;
        $sth->bind_param_array(1, \@pe1);
        $sth->bind_param_array(2, \@p2);
        insert($dbh, $sth, {commit => 0, error => 1, sts => undef,
                            affected => undef, tuple => [1, 1, 1, [], 1], %$ref});
        check_data($dbh, [@pe1[0..2],$pe1[4]], [@p2[0..2], $p2[4]]);
    }
}

sub fetch_sub
{
    diag("fetch_sub $fetch_row");
    if ($fetch_row == @p1) {
        diag('returning undef');
        $fetch_row = 0;
        return;
    }

    return [$p1[$fetch_row], $p2[$fetch_row++]];
}

# test insertion via execute_array and ArrayTupleFetch
sub row_wise
{
    my ($dbh, $ref) = @_;

    diag("row_size via execute_for_fetch");

    $fetch_row = 0;
    clear_table($dbh, $table);
    my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
    insert($dbh, $sth,
           {commit => 0, error => 0, sts => 5, affected => 5,
            tuple => [1, 1, 1, 1, 1], %$ref,
            fetch => \&fetch_sub});

    # NOTE: I'd like to do the following test but it requires Multiple
    # Active Statements and although I can find ODBC drivers which do this
    # it is not easy (if at all possible) to know if an ODBC driver can
    # handle MAS or not. If it errors the driver probably does not have MAS
    # so the error is ignored and a diagnostic is output.
    diag("row_size via select");
    clear_table($dbh, $table);
    $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
    my $sth2 = $dbh->prepare(qq/select * from $table2/);
    ok($sth2->execute, 'execute on second table') or diag($sth2->errstr);
    ok($sth2->{Executed}, 'second statement is in executed state');
    my $res = insert($dbh, $sth,
           {commit => 0, error => 0, sts => 5, affected => 5,
            tuple => [1, 1, 1, 1, 1], %$ref,
            fetch => $sth2, requires_mas => 1});
    return if $res && $res eq 'mas'; # aborted , does not seem to support MAS
    check_data($dbh, \@p1, \@p2);
    #my $res = $dbh->selectall_arrayref("select * from $table2");
    #print Dumper($res);
}

# test updates
sub update
{
    my ($dbh, $ref) = @_;

    diag("update test");

    $fetch_row = 0;
    clear_table($dbh, $table);
    my $sth = $dbh->prepare(qq/insert into $table values(?,?)/);
    insert($dbh, $sth,
           {commit => 0, error => 0, sts => 5, affected => 5,
            tuple => [1, 1, 1, 1, 1], %$ref,
            fetch => \&fetch_sub});
    check_data($dbh, \@p1, \@p2);

    $sth = $dbh->prepare(qq/update $table set b = ? where a = ?/);
    # NOTE, this also checks you can pass a scalar to bind_param_array
    $sth->bind_param_array(1, 'fred');
    $sth->bind_param_array(2, \@p1);
    insert($dbh, $sth,
           {commit => 0, error => 0, sts => 5, affected => 5,
            tuple => [1, 1, 1, 1, 1], %$ref});
    check_data($dbh, \@p1, [qw(fred fred fred fred fred)]);

    $sth = $dbh->prepare(qq/update $table set b = ? where a = ?/);
    # NOTE, this also checks you can pass a scalar to bind_param_array
    $sth->bind_param_array(1, 'dave');
    my @pe1 = @p1;
    $pe1[-1] = 10;              # non-existant row
    $sth->bind_param_array(2, \@pe1);
    insert($dbh, $sth,
           {commit => 0, error => 0, sts => 5, affected => 4,
            tuple => [1, 1, 1, 1, '0E0'], %$ref});
    check_data($dbh, \@p1, [qw(dave dave dave dave fred)]);

    $sth = $dbh->prepare(qq/update $table set b = ? where b like ?/);
    # NOTE, this also checks you can pass a scalar to bind_param_array
    $sth->bind_param_array(1, 'pete');
    $sth->bind_param_array(2, ['dave%', 'fred%']);
    insert($dbh, $sth,
           {commit => 0, error => 0, sts => 2, affected => 5,
            tuple => [4, 1], %$ref});
    check_data($dbh, \@p1, [qw(pete pete pete pete pete)]);


}

$dbh->{RaiseError} = 1;
$dbh->{PrintError} = 0;
$dbh->{ChopBlanks} = 1;
$dbh->{HandleError} = \&error_handler;
$dbh->{AutoCommit} = 1;

eval {drop_table_local($dbh)};

ok(create_table_local($dbh), "create test table") or exit 1;
simple($dbh, {array_context => 1, raise => 1});
simple($dbh, {array_context => 0, raise => 1});
error($dbh, {array_context => 1, raise => 1});
error($dbh, {array_context => 0, raise => 1});
error($dbh, {array_context => 1, raise => 0});
error($dbh, {array_context => 0, raise => 0});

row_wise($dbh, {array_context => 1, raise => 1});

update($dbh, {array_context => 1, raise => 1});
