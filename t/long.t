#!/usr/local/bin/perl -w

use DBI;
use DBD::Oracle qw(:ora_types ORA_OCI);
use strict;

$| = 1;
my $t = 0;
my $failed = 0;
my $oflng;
my $lrl_limit;
my $table = "dbd_ora__drop_me";

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

unless(create_table("lng LONG")) {
    warn "Unable to create test table ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
}


my @test_sets = ([ "LONG", undef ], [ "LONG RAW", ORA_LONGRAW ]);
push @test_sets, [ "CLOB", ORA_CLOB ], [ "BLOB", ORA_BLOB ] if ORA_OCI >= 8;

my $sz = 8; # Min 8 == 80KB, max = ???
my $tests;
my $tests_per_set = 35;
$tests = @test_sets * $tests_per_set;
print "1..$tests\n";

my($sth, $p1, $p2, $tmp, @tmp);
#$dbh->trace(4);

foreach (@test_sets) {
    run_long_tests( @$_ );
}


sub run_long_tests {
    my ($type_name, $type_num) = @_;

my $long_data0 =  "\177.\0.X"     x 2048;         #  10KB   < 64KB
my $long_data1 = ("1234567890"    x 1024) x $sz;  # 520KB  >> 64KB & > long_data2
my $long_data2 = ("abcdefabcd"    x 1024) x  7;   #  70KB   > 64KB & < long_data1

$long_data2 = "00FF" x (length($long_data2) / 2) if $type_name =~ /RAW/i;

print "long_data0 length ",length($long_data0),"\n";
print "long_data1 length ",length($long_data1),"\n";
print "long_data2 length ",length($long_data2),"\n";
 
if (!create_table("lng $type_name", 1)) {
    # typically OCI 8 client talking to Oracle 7 database
    warn "Unable to create test table for '$type_name' data ($DBI::err). Tests skipped.\n";
    foreach (1..$tests_per_set) { ok(0, 1) }
    return;
}

print " --- insert some $type_name data\n";
ok(0, $sth = $dbh->prepare("insert into $table values (?, ?)"), 1);
$sth->bind_param(2, undef, { ora_type => $type_num }) or die $DBI::errstr
    if $type_num;
ok(0, $sth->execute(40, $long_data0), 1);
ok(0, $sth->execute(41, $long_data1), 1);
ok(0, $sth->execute(42, $long_data2), 1);


print " --- fetch it back again -- truncated - LongTruncOk == 1\n";
$dbh->{LongReadLen} = 20;
# This behaviour isn't specified anywhere, sigh:
my $out_len = ($type_name =~ /RAW/i) ? 40 : 20;
$dbh->{LongTruncOk} =  1;
ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
ok(0, $sth->execute, 1);
ok(0, $tmp = $sth->fetchall_arrayref, 1);
ok(0, $tmp->[0][1] eq substr($long_data0,0,$out_len), length($tmp->[0][1]));
ok(0, $tmp->[1][1] eq substr($long_data1,0,$out_len), length($tmp->[1][1]));
ok(0, $tmp->[2][1] eq substr($long_data2,0,$out_len),
	cdif($tmp->[2][1], substr($long_data2,0,$out_len), "Len ".length($tmp->[2][1])) );


print " --- fetch it back again -- truncated - LongTruncOk == 0\n";
$dbh->{LongReadLen} = 1024 * 50; # first fits, second doesn't
$dbh->{LongTruncOk} =  0;
ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
ok(0, $sth->execute, 1);
ok(0, $tmp = $sth->fetchrow_arrayref, 1);
ok(0, $tmp->[1] eq $long_data0, length($tmp->[1]));
ok(0, !defined $sth->fetchrow_arrayref, 1);
ok(0, $sth->err == 1406 || $sth->err == 24345, $sth->errstr);


print " --- fetch it back again -- complete - LongTruncOk == 0\n";
$dbh->{LongReadLen} = (65535 * 10) - 100;
$dbh->{LongTruncOk} =  0;
ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
ok(0, $sth->execute, 1);
ok(0, $tmp = $sth->fetchrow_arrayref, 1);
ok(0, $tmp->[1] eq $long_data0, length($tmp->[1]));

if ($tmp = $sth->fetchrow_arrayref) {
 ok(0, $tmp, 1);
 ok(0, $tmp->[1] eq $long_data1, length($tmp->[1]));
 ok(0, $tmp = $sth->fetchrow_arrayref, 1);
 ok(0, $tmp->[1] eq $long_data2,
	cdif($tmp->[1],$long_data2, "Len ".length($tmp->[1])) );
}
else {
 $lrl_limit = 1;
 ok(0,1); ok(0,1); ok(0,1); ok(0,1);
}


print " --- fetch it back again -- via blob_read\n";
if (ORA_OCI >= 8 && $type_name =~ /LONG/i) {
    print "Skipped blob_read tests for LONGs with OCI8 - not currently supported.\n";
    foreach (1..11) { ok(0,1) }
    return;
}
#$dbh->trace(4);
$dbh->{LongReadLen} = 1024 * 90;
$dbh->{LongTruncOk} =  1;
ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
ok(0, $sth->execute, 1);
ok(0, $tmp = $sth->fetchrow_arrayref, 1);

ok(0, blob_read_all($sth, 1, \$p1, 4096) == length($long_data0), 1);
ok(0, $p1 eq $long_data0, 1);

ok(0, $tmp = $sth->fetchrow_arrayref, 1);
ok(0, blob_read_all($sth, 1, \$p1, 12345) == length($long_data1), 1);
ok(0, $p1 eq $long_data1, 1);

ok(0, $tmp = $sth->fetchrow_arrayref, 1);
my $len = blob_read_all($sth, 1, \$p1, 34567);

if ($len == length($long_data2)) {
    ok(0, $len == length($long_data2), $len);
	# Oracle may return the right length but corrupt the string.
    ok(0, $p1 eq $long_data2, cdif($p1, $long_data2) );
}
elsif ($len == length($long_data1) && DBD::Oracle::ORA_OCI() == 7) {
    $oflng = __LINE__;
	# The bug:
	#	If you use blob_read to read a LONG field
	#	and then fetch another row
	#	and use blob_read to read that LONG field
	# 	If the second LONG is shorter than the first
	#	then the second long will appear to have the
	#	longer portion of first appended to it.
    ok(0, 1);
    ok(0, 1, 0);
}
else {
    ok(0, 0, "Fetched length $len, expected ".length($long_data2));
    ok(0, 0, 0);
}

} # end of run_long_tests

if ($oflng) {
    warn "\nYour version of Oracle 7 OCI has a bug that effects the (undocumented) blob_read method.\n";
    warn "See the t/long.t script near line $oflng for more information.\n";
    warn "(You can safely ignore this if you don't use the blob_read method.)\n";
}

if ($lrl_limit) {
    warn "\nThe maximum valid value of \$h->{LongReadLen} when fetching LONGs is currently 65535.\n";
    warn "There's no limit when fetching LOB types.\n" if ORA_OCI() >= 8;
}

if ($failed) {
    warn "\nSome tests for LONG data type handling failed. These are generally Oracle bugs.\n";
    warn "Please report this to the dbi-users mailing list, and include the\n";
    warn "Oracle version number of both the client and the server.\n";
    warn "Please also include the output of the 'perl -V' command.\n";
    warn "(If you can, please study t/long.t to investigate the cause.\n";
    warn "Feel free to edit the tests to see what's happening in more detail.\n";
    warn "Especially by adding trace() calls around the failing tests.\n";
    warn "Run the tests manually using the command \"perl -Mblib t/long.t\")\n";
    warn "Meanwhile, if the other tests have passed you can use DBD::Oracle.\n\n";
}

exit 0;
BEGIN { $tests = 27 }
END {
    $dbh->do(qq{ drop table $table }) if $dbh;
}
# end.


# ----

sub create_table {
    my ($fields, $drop) = @_;
    my $sql = "create table $table ( idx integer, $fields )";
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

sub blob_read_all {
    my ($sth, $field_idx, $blob_ref, $lump) = @_;

    $lump ||= 4096; # use benchmarks to get best value for you
    my $offset = 0;
    my @frags;
    while (1) {
	my $frag = $sth->blob_read($field_idx, $offset, $lump);
	return unless defined $frag;
	my $len = length $frag;
	last unless $len;
	push @frags, $frag;
	$offset += $len;
	#warn "offset $offset, len $len\n";
    }
    $$blob_ref = join "", @frags;
    return length($$blob_ref);
}

sub unc {
    my @str = @_;
    foreach (@str) { s/([\000-\037\177-\377])/ sprintf "\\%03o", ord($_) /eg; }
    return join "", @str unless wantarray;
    return @str;
}

sub cdif {
    my ($s1, $s2, $msg) = @_;
    $msg = ($msg) ? ", $msg" : "";
    my ($l1, $l2) = (length($s1), length($s2));
    return "Strings are identical$msg" if $s1 eq $s2;
    return "Strings are of different lengths ($l1 vs $l2)$msg" # check substr matches?
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
