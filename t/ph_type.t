#!perl -w

my $muted = 1;	# set to 0 to see tests fail etc etc

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

use strict;
use DBI qw(neat);
use DBD::Oracle qw(ORA_OCI);

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dsn    = $ENV{ORACLE_DSN}    || 'dbi:Oracle:';
my $dbh = DBI->connect($dsn, $dbuser, '', {
	AutoCommit => 0,
	PrintError => 1,
	FetchHashKeyName => 'NAME_lc',
});

unless($dbh) {
	warn "Unable to connect to Oracle ($DBI::errstr)\nTests skipped.\n";
	print "1..0\n";
	exit 0;
}

use vars qw($tests);
$| = 1;
$^W = 1;
print "1..$tests\n";

my ($sth,$expect,$tmp);
my $table = "dbd_oracle_test__drop_me";

# drop table but don't warn if not there
eval {
  local $dbh->{PrintError} = 0;
  $dbh->do("DROP TABLE $table");
};
#warn $@ if $@;

ok(0, $dbh->do("CREATE TABLE $table (test VARCHAR2(2), foo VARCHAR2(20))"));

my $val_with_trailing_space = "trailing ";
my $val_with_embedded_nul = "embedded\0nul";

my @tests =
 ([  1, "VARCHAR2", 0, 1, 0 ],	# DBD::Oracle default
  [  5, "STRING",   1, 0, 1 ],
  [ 96, "CHAR",     1, 1, 0 ],
  [ 97, "CHARZ",    1, 0, 1 ]);

for my $test_ary (@tests) {
  my ($ph_type, $name, $trailing_space_ok, $embed_nul_ok, $trace) = @$test_ary;
  print "#\n";
  print "# testing $name (ora_type $ph_type) ...\n";
  print "#\n";
  if ($muted && $trace) {
	print "# skipping tests\n";
	foreach (1..12) { ok(0,1) }
	next;
  }
  $dbh->trace(8) if $trace && !$muted;

  ok(0, $dbh->{ora_ph_type} =  $ph_type );
  ok(0, $dbh->{ora_ph_type} == $ph_type );

  ok(0, $sth = $dbh->prepare("INSERT INTO $table VALUES (?,?)"));
  ok(0, $sth->execute("ts", $val_with_trailing_space));
  ok(0, $sth->execute("en", $val_with_embedded_nul));
  ok(0, $sth->execute("em", '')); # empty string

  ok(0, $tmp = $dbh->selectall_hashref(qq{
	SELECT test, foo, length(foo) as len, nvl(foo,'ISNULL') as isnull
	FROM $table
  }, "test"));
  ok(0, keys(%$tmp) == 3);
  ok(0, $tmp->{en}->{foo});
  ok(0, $tmp->{ts}->{foo});
  $dbh->trace(0);
  ok(0, $dbh->rollback );

  eval {
    require Data::Dumper;
    $Data::Dumper::Useqq = $Data::Dumper::Useqq =1;
    $Data::Dumper::Terse = $Data::Dumper::Terse =1;
    $Data::Dumper::Indent= $Data::Dumper::Indent=1;
    print Dumper($tmp);
  };

  $expect = $val_with_trailing_space;
  $expect =~ s/\s+$// unless $trailing_space_ok;
  my $ts_pass = ($tmp->{ts}->{foo} eq $expect);
  if (ORA_OCI==7 && $name eq 'VARCHAR2') {
    warn " OCI7 trailing space behaviour differs" if -f "MANIFEST.SKIP";
    $ts_pass = 1;
  }
  ok(0, $ts_pass,
	sprintf("expected %s but got %s for $name", neat($expect),neat($tmp->{ts}->{foo})) );

  $expect = $val_with_embedded_nul;
  $expect =~ s/\0.*// unless $embed_nul_ok;
  ok(0, $tmp->{en}->{foo} eq $expect,
	sprintf("expected %s but got %s for $name", neat($expect),neat($tmp->{en}->{foo})) );

last if $trace;
}

ok(0, $dbh->do("DROP TABLE $table"));
ok(0, $dbh->disconnect );

BEGIN { $tests = 53 }


__END__

Date: Mon, 05 Feb 2001 04:29:47 -0600
From: "James E Jurach Jr." <muaddib@fundsxpress.com>
Subject: Re: DBD::Oracle - Bind value of space wrongly interpreted as NULL
To: Tim Bunce <Tim.Bunce@ig.co.uk>, dbi-users@isc.org
cc: James Jurach <jjurach@fundsxpress.com>
Reply-to: "James E. Jurach Jr." <jjurach@fundsxpress.com>
Message-ID: <200102051029.EAA00487@umgah.mesas.com>

Tim Bunce wrote on 08/11/2000 10:22:14:
> I need a volunteer to write a test script (like the other t/*.t files)
> that will... create a table with NULL and NOT NULL variants of CHAR and
> VARCHAR columns, and then do a series of inserts and selects with and
> without trailing spaces etc with ora_ph_type set to various values.
> 
> Wouldn`t be too hard to do as a series of nested loops (a little like
> t/long.t, only simpler) driven by a data structure that says what to
> expect in each case.
> 
> Any volunteers? This is your chance to give back...

We've been having problems migrating from OCI_V7 to OCI_V8 using DBD-Oracle
because of VARCHAR2 trailing space issues.  I have tried and failed to get
the $dbh->{ora_ph_type} trick mentioned in Changes to work.  Invariably,
when ora_ph_type is set to "5" (or "97"), I get the following error from the
following pseudocode:

 $dbh->{ora_ph_type} = 5;
 $dbh->do("CREATE TABLE foobar (foo VARCHAR2(20))");
 $sth = $dbh->prepare("INSERT INTO foobar VALUES (?)");
 $sth->execute("trailing ");

   ORA-01461: can bind a LONG value only for insert into a LONG column
	(DBD ERROR: OCIStmtExecute)

I have taken you up on your challenge to produce a test file, t/ph_type.t.
It doesn't do much right now, so feel free to beef it up.  At least it
reproduces the problem.

Let me know if there is anything more I can do.

james

t/ph_type.t:
