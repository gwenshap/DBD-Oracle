#!/usr/local/bin/perl -w

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
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
if (!$dbh->prepare(q{begin RAISE INVALID_NUMBER; end;}) && $dbh->err==900) {
	warn "Your Oracle server doesn't support PL/SQL - Tests skipped.\n";
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
    begin RAISE_APPLICATION_ERROR(-20101,'app error'); end;
}), 1);

# ORA-20101: app error
ok(0, ! $csr->execute, 1);
ok(0, $DBI::err    == 20101);
ok(0, $DBI::errstr =~ m/app error/);


# --- test raise_application_error with 'in' parameters
ok(0, $csr = $dbh->prepare(q{
    declare err_num number; err_msg char(510);
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
	:arg := :arg * 2;
    end;
}), 1);

$p1 = 3;
ok(0, $csr->bind_param_inout(':arg', \$p1, 100), 1);
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
	:arg := nvl(nls_upper(:arg), 'null');
	:arg := :arg || '!';
    end;
}), 1);

undef $p1;
$p1 = "hello world";
ok(0, $csr->bind_param_inout(':arg', \$p1, 1000), 1);
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

my @ary = qw(foo bar baz boo);
ok(0, $dbh->func(@ary, 'dbms_output_put'), 1);

@ary = scalar $dbh->func('dbms_output_get');	# scalar context
ok(0, @ary==1 && $ary[0] eq 'foo', 0);

@ary = scalar $dbh->func('dbms_output_get');	# scalar context
ok(0, @ary==1 && $ary[0] eq 'bar', 0);

@ary = $dbh->func('dbms_output_get');			# list context
ok(0, join(':',@ary) eq 'baz:boo', 0);
$dbh->{PrintError} = 0;

    # To do
    #   test NULLs at first bind
    #   NULLs later binds.
    #   returning NULLs
    #   multiple params, mixed types and in only vs inout

ok(0,  $dbh->ping);
$dbh->disconnect;
ok(0, !$dbh->ping);

exit 0;
BEGIN { $tests = 37 }
# end.

__END__
t/plsql.............ORA-06502: PL/SQL: numeric or value error
ORA-06512: at line 4 (DBD: oexec error)
Use of uninitialized value at t/plsql.t line 120.
Error in PL/SQL block
3.5: PLS-00103: The symbol "an optional basic declaration item" was ignored.
