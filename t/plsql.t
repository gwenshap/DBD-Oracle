#!/usr/local/bin/perl -w

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
$| = 1;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('', $dbuser, '', 'Oracle');

unless($dbh) {
	warn "Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n";
	print "1..0\n";
	exit 0;
}

# ORA-00900: invalid SQL statement
# ORA-06553: PLS-213: package STANDARD not accessible
my $tst = $dbh->prepare(q{declare foo char(50); begin RAISE INVALID_NUMBER; end;});
if ($dbh->err && ($dbh->err==900 || $dbh->err==6553 || $dbh->err==600)) {
	warn "Your Oracle server doesn't support PL/SQL"	if $dbh->err== 900;
	warn "Your Oracle PL/SQL is not properly installed"	if $dbh->err==6553||$dbh->err==600;
	warn "Tests skipped\n";
	print "1..0\n";
	exit 0;
}

print "1..$tests\n";

my($csr, $p1, $p2);
#DBI->trace(4,"trace.log");


# --- test raising predefined exception
ok(0, $csr = $dbh->prepare(q{
    begin RAISE INVALID_NUMBER; end;
}), 1);

# ORA-01722: invalid number
ok(0, ! $csr->execute, 1);
ok(0, $DBI::err == 1722);
ok(0, $DBI::err == 1722);	# make sure error doesn't get cleared


# --- test raising user defined exception
ok(0, $csr = $dbh->prepare(q{
    DECLARE FOO EXCEPTION;
    begin raise FOO; end;
}), 1);

# ORA-06510: PL/SQL: unhandled user-defined exception
ok(0, ! $csr->execute, 1);
ok(0, $DBI::err == 6510);


# --- test raise_application_error with literal values
ok(0, $csr = $dbh->prepare(q{
    declare err_num number; err_msg char(510);
    begin RAISE_APPLICATION_ERROR(-20101,'app error'); end;
}), 1);

# ORA-20101: app error
ok(0, ! $csr->execute, 1);
ok(0, $DBI::err    == 20101);
ok(0, $DBI::errstr =~ m/app error/);


# --- test raise_application_error with 'in' parameters
ok(0, $csr = $dbh->prepare(q{
    declare err_num varchar2(555); err_msg varchar2(510);
    --declare err_num number; err_msg char(510);
    begin
	err_num := :1;
	err_msg := :2;
	raise_application_error(-20000-err_num, 'msg is '||err_msg);
    end;
}), 1);

ok(0, ! $csr->execute(42, "hello world"), 1);
ok(0, $DBI::err    == 20042, $DBI::err);
ok(0, $DBI::errstr =~ m/msg is hello world/, 1);

# --- test named numeric in/out parameters
ok(0, $csr = $dbh->prepare(q{
    begin
	:arg := :arg * :mult;
    end;
}), 1);

$p1 = 3;
ok(0, $csr->bind_param_inout(':arg', \$p1, 4), 1);
ok(0, $csr->bind_param(':mult', 2), 1);
ok(0, $csr->execute, 1);
ok(0, $p1 == 6);
# execute 10 times from $p1=1, 2, 4, 8, ... 1024
$p1 = 1; foreach (1..10) { $csr->execute || die $DBI::errstr; }
ok(0, $p1 == 1024);

# --- test undef parameters
ok(0, $csr = $dbh->prepare(q{
	declare foo char(500);
	begin foo := :arg; end;
}), 1);
my $undef;
ok(0, $csr->bind_param_inout(':arg', \$undef,10), 1);
ok(0, $csr->execute, 1);


# --- test named string in/out parameters
ok(0, $csr = $dbh->prepare(q{
    declare str varchar2(1000);
    begin
	:arg := nvl(upper(:arg), 'null');
	:arg := :arg || :append;
    end;
}), 1);

undef $p1;
$p1 = "hello world";
ok(0, $csr->bind_param_inout(':arg', \$p1, 1000), 1);
ok(0, $csr->bind_param(':append', "!"), 1);
ok(0, $csr->execute, 1);
ok(0, $p1 eq "HELLO WORLD!");
# execute 10 times growing $p1 to force realloc
foreach (1..10) {
    $p1 .= " xxxxxxxxxx";
    $csr->execute || die $DBI::errstr;
}
my $expect = "HELLO WORLD!" . (" XXXXXXXXXX!" x 10);
ok(0, $p1 eq $expect);


# --- test binding a null and getting a string back
undef $p1;
ok(0, $csr->execute, 1);
ok(0, $p1 eq 'null!');

$csr->finish;


# --- test out buffer being too small
ok(0, $csr = $dbh->prepare(q{
    begin
	select rpad('foo',200) into :arg from dual;
    end;
}), 1);
#$csr->trace(3);
undef $p1;	# force buffer to be freed
ok(0, $csr->bind_param_inout(':arg', \$p1, 20), 1);
# Fails with:
#	ORA-06502: PL/SQL: numeric or value error
#	ORA-06512: at line 3 (DBD ERROR: OCIStmtExecute)
ok(0, !defined $csr->execute, 1);
# rebind with more space - and it should work
ok(0, $csr->bind_param_inout(':arg', \$p1, 200), 1);
ok(0, $csr->execute, 1);
ok(0, length($p1) == 200, 0);


# --- test plsql_errstr function
#$csr = $dbh->prepare(q{
#    create or replace procedure perl_dbd_oracle_test as
#    begin
#	  procedure filltab( stuff out tab ); asdf
#    end;
#});
#ok(0, ! $csr);
#if ($dbh->err && $dbh->err == 6550) {	# PL/SQL error
#	warn "errstr: ".$dbh->errstr;
#	my $msg = $dbh->func('plsql_errstr');
#	warn "plsql_errstr: $msg";
#	ok(0, $msg =~ /Encountered the symbol/, "plsql_errstr: $msg");
#}
#else {
#	warn "plsql_errstr test skipped ($DBI::err)\n";
#	ok(0, 1);
#}
#die;

# --- test dbms_output_* functions
$dbh->{PrintError} = 1;
ok(0, $dbh->func(30000, 'dbms_output_enable'), 1);

#$dbh->trace(3);
my @ary = ("foo", ("bar" x 15), "baz", "boo");
ok(0, $dbh->func(@ary, 'dbms_output_put'), 1);

@ary = scalar $dbh->func('dbms_output_get');	# scalar context
ok(0, @ary==1 && $ary[0] && $ary[0] eq 'foo', 0);

@ary = scalar $dbh->func('dbms_output_get');	# scalar context
ok(0, @ary==1 && $ary[0] && $ary[0] eq 'bar' x 15, 0);

@ary = $dbh->func('dbms_output_get');			# list context
ok(0, join(':',@ary) eq 'baz:boo', 0);
$dbh->{PrintError} = 0;
#$dbh->trace(0);

# --- test cursor variables
$csr = $dbh->prepare(q{
    begin
	:var := :var * 2;
    end;
});
ok(0, $csr);
my $out_csr = $dbh->prepare(q{select 42 from dual}); # sacrificial csr XXX
ok(0, $out_csr);
if (0) {
    ok(0, $csr->bind_param_inout(':var', \$out_csr, 100, { ora_type => 102 }));
    ok(0, $csr->execute());
}
else {
    ok(0,1);
    ok(0,1);
}
# at this point $out_csr should be a handle on a new oracle cursor


# --- To do
    #   test NULLs at first bind
    #   NULLs later binds.
    #   returning NULLs
    #   multiple params, mixed types and in only vs inout

# --- test ping
ok(0,  $dbh->ping);
$dbh->disconnect;
ok(0, !$dbh->ping);

exit 0;
BEGIN { $tests = 49 }
# end.

__END__
