#!perl -w

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n"
	  : print "# failed test $t at line ".(caller)[2]."\nnot ok $t\n";
	if (!$ok && $warn) {
		$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
		warn "$warn\n";
	}
}

use DBI;
use DBD::Oracle qw(ORA_RSET);
use strict;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '', { PrintError => 0 });

unless ($dbh) {
	warn "Unable to connect to Oracle as $dbuser ($DBI::errstr)\nTests skipped.\n";
	print "1..0\n";
	exit 0;
}

my $tests = 16;

print "1..$tests\n";

# ref cursors may be slow due to oracle bug 3735785
# believed fixed in
#	 9.2.0.6 (Server Patch Set) 
#	10.1.0.4 (Server Patch Set) 
#	10.2.0.1 (Base Release)

ok( 1,
  my $outer = $dbh->prepare(q{
    SELECT object_name, CURSOR(SELECT object_name FROM dual)
    FROM all_objects WHERE rownum <= 5
  })
);
ok( 2, $outer->{ora_types}[1] == ORA_RSET);
ok( 3, $outer->execute);
ok( 4, my @row1 = $outer->fetchrow_array);
my $inner1 = $row1[1];
ok( 5, ref $inner1 eq 'DBI::st');
ok( 6, $inner1->{Active});
ok( 7, my @row1_1 = $inner1->fetchrow_array);
ok( 8, $row1[0] eq $row1_1[0]);
ok( 9, $inner1->{Active});
ok(10, my @row2 = $outer->fetchrow_array);
ok(11, !$inner1->{Active});
ok(12, !$inner1->fetch);
ok(13, $dbh->err == -1);
ok(14, $dbh->errstr =~ / defunct /);
ok(15, $outer->finish);
ok(16, $dbh->{ActiveKids} == 0);


#########################################################################
# Fetch speed test: START
#########################################################################

$dbh->{RaiseError} = 1;

sub timed_fetch {
  my ($rs,$caption) = @_;
  my $row_count = 0;
  my $tm_start = DBI::dbi_time();
  $row_count++ while $rs->fetch;
  my $elapsed = DBI::dbi_time() - $tm_start;
  print "Fetched $row_count rows ($caption): $elapsed secs.\n";
  return $elapsed;
}

##################################################
# regular select
##################################################
my $sql1 = q{
    SELECT object_name
    FROM (SELECT object_name FROM all_objects WHERE ROWNUM<=70),
	 (SELECT           1 FROM all_objects WHERE ROWNUM<=70)
};
$outer = $dbh->prepare($sql1);
$outer->execute();
my $dur_std = timed_fetch($outer,'select');

##################################################
# nested cursor
##################################################
$outer = $dbh->prepare("SELECT CURSOR($sql1) FROM DUAL");
$outer->execute();
my $ref_csr = $outer->fetchrow_arrayref->[0];
my $dur_ref = timed_fetch($ref_csr,'nested cursor');

#########################################################################
# Fetch speed test: END
#########################################################################

exit 0;

