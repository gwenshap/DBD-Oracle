#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

use DBI qw(:sql_types);
use Devel::Peek;
use B qw( svref_2object SVf_IOK SVf_NOK SVf_POK );

unshift @INC ,'t';
require 'nchar_test_lib.pl';

sub is_iv {
   my $sv = svref_2object(my $ref = \$_[0]);
   my $flags = $sv->FLAGS;

   # See http://www.perlmonks.org/?node_id=971411
   my $x = $sv->can('PV') ? $sv->PV : undef;

   if (wantarray) {
       return ($flags & SVf_IOK, $x);
   } else {
       return $flags & SVf_IOK;
   }
}

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

my $dbh = DBI->connect( $dsn, $dbuser, '',  {
    PrintError => 0, FetchHashKeyName =>'NAME_lc'});

plan skip_all => "unable to connect to Oracle database" if not $dbh;

plan tests => 2;

my $s = $dbh->prepare(q/select 1 as one from dual/);
$s->execute;

$s->bind_col (1, undef, {TYPE => SQL_INTEGER, DiscardString => 1});

my $list = $s->fetchall_arrayref({});

is($list->[0]{one}, 1, "correct value returned");
ok(is_iv($list->[0]{one}), "ivok") or Dump($list->[0]{one});

$dbh->disconnect;

