#!perl -w

use DBI;
use DBD::Oracle qw(:ora_types ORA_OCI);
use Data::Dumper;
use Math::BigInt;
use strict;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

sub ok ($$;$);

$| = 1;
my $t = 0;
my $failed = 0;
my %ocibug;
my $table = "dbd_ora__drop_me" . ($ENV{DBD_ORACLE_SEQ}||'');


my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
	AutoCommit => 1,
	PrintError => 0,
});

unless($dbh) {
    warn "Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
}

my $utf8_test = ($] >= 5.006)
	&& client_ochar_is_utf8() # for correct output (utf8 bind vars should be fine regardless)
	&& ($dbh->ora_can_unicode() & 2);
print "Including unicode test\n" if $utf8_test;

unless(create_test_table("str CHAR(10)", 1)) {
    warn "Unable to create test table ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
}


my @test_sets = (
	[ "CHAR(10)",     10 ],
	[ "VARCHAR(10)",  10 ],
	[ "VARCHAR2(10)", 10 ],
);

# Set size of test data (in 10KB units)
#	Minimum value 3 (else tests fail because of assumptions)
#	Normal  value 8 (to test 64KB threshold well)
my $sz = 8;

my $tests = 2;
my $tests_per_set = 11;
$tests += @test_sets * $tests_per_set;
print "1..$tests\n";

my($sth, $p1, $p2, $tmp, @tmp);
#$dbh->trace(4);

foreach (@test_sets) {
    run_select_tests( @$_ );
}


sub run_select_tests {
  my ($type_name, $field_len) = @_;
  
  my $data0;
  if ($utf8_test) {
    $data0 = eval q{ "0\x{263A}xyX" }; #this includes the smiley from perlunicode (lab) BTW: it is busted
  } else {
    $data0 = "0\177x\0X";
  }
  my $data1 = "1234567890";
  my $data2 = "2bcdefabcd";
  
  if (!create_test_table("lng $type_name", 1)) {
    # typically OCI 8 client talking to Oracle 7 database
    warn "Unable to create test table for '$type_name' data ($DBI::err). Tests skipped.\n";
    foreach (1..$tests_per_set) { ok(0, 1) }
    return;
  }
  
  print " --- insert some $type_name data\n";
  ok(0, $sth = $dbh->prepare("insert into $table values (?, ?, SYSDATE)"), 1);
  ok(0, $sth->execute(40, $data0), 1);
  ok(0, $sth->execute(Math::BigInt->new(41), $data1), 1); # bind an overloaded value
  ok(0, $sth->execute(42, $data2), 1);

  print " --- try to insert a string that's too long\n";
  ok(0, !$sth->execute(43, "12345678901234567890"), 1);
  
  print " --- fetch $type_name data back again\n";
  
  ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
  ok(0, $sth->execute, 1);
  ok(0, $tmp = $sth->fetchall_arrayref, 1);
  # allow for padded blanks
  ok(0, $tmp->[0][1] =~ m/$data0/,
     cdif($tmp->[0][1], $data0, "Len ".length($tmp->[0][1])) );
  ok(0, $tmp->[1][1] =~ m/$data1/,
     cdif($tmp->[1][1], $data1, "Len ".length($tmp->[1][1])) );
  ok(0, $tmp->[2][1] =~ m/$data2/,
     cdif($tmp->[2][1], $data2, "Len ".length($tmp->[2][1])) );
  
  
} # end of run_select_tests


if (0) { # UNION ALL causes Oracle 9 (not 8) to describe col1 as zero length
# causing "ORA-24345: A Truncation or null fetch error occurred" error
# Looks like an Oracle bug
$dbh->trace(9);
ok 0, $sth = $dbh->prepare(qq{
	SELECT :HeadCrncy FROM DUAL
	UNION ALL
	SELECT :HeadCrncy FROM DUAL
});
$dbh->trace(0);
ok 0, $sth->execute("EUR");
ok 0, $tmp = $sth->fetchall_arrayref;
use Data::Dumper;
die Dumper $tmp;
}


# $dbh->{USER} is just there so it works for old DBI's before Username was added
my @pk = $dbh->primary_key(undef, $dbh->{USER}||$dbh->{Username}, uc $table);
print "primary_key($table): ".Dumper(\@pk);
ok(0, @pk);
ok(0, join(",",@pk) eq 'DT,IDX');

exit 0;
END {
    $dbh->do(qq{ drop table $table }) if $dbh;
}
# end.


# ----

sub create_test_table {
    my ($fields, $drop) = @_;
    my $sql = qq{create table $table (
	idx integer,
	$fields,
	dt date,
	primary key (dt, idx)
    )};
    $dbh->do(qq{ drop table $table }) if $drop;
    $dbh->do($sql);
    if ($dbh->err && $dbh->err==955) {
	$dbh->do(qq{ drop table $table });
	warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
	$dbh->do($sql);
    }
    return 0 if $dbh->err;
    print "$sql\n";
    return 1;
}


sub cdif {
    my ($s1, $s2, $msg) = @_;
    $msg = ($msg) ? ", $msg" : "";
    my ($l1, $l2) = (length($s1), length($s2));
    return "Strings are identical$msg" if $s1 eq $s2;
    return "Strings are of different lengths ($l1 vs $l2)($s1 vs $s2)$msg" # check substr matches?
	if $l1 != $l2;
	
    my $i;
    for($i=0; $i < $l1; ++$i) {
	my ($c1,$c2) = (ord(substr($s1,$i,1)), ord(substr($s2,$i,1)));
	next if $c1 == $c2;
        return sprintf "Strings differ at position %d (\\%03o vs \\%03o)$msg",
		$i,$c1,$c2;
    }
    return "(cdif error $l1/$l2/$i)";
}


sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    $warn ||= '';
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    if ($ok) {
	print "ok $t\n";
    }
    else {
	$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
	warn "# failed test $t at line ".(caller)[2].". $warn\n";
	print "not ok $t\n";
	++$failed;
    }
}

__END__
