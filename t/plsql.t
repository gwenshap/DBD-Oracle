#!/usr/local/bin/perl -w

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
	if (!$ok && $warn) {
		$warn = $DBI::errstr if $warn eq '1';
		warn "$warn\n";
	}
}

use DBI;

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('', $dbuser, '', 'Oracle');

unless($dbh) {
	warn "Unable to connect to Oracle ($DBI::errstr)\n";
	print "1..0\n";
	exit 0;
}

print "1..$tests\n";

my($csr, $p1, $p2);


# --- test raising predefined exception
ok(0, $csr = $dbh->prepare(q{
    begin RAISE INVALID_NUMBER; end;
}), 1);

# ORA-01722: invalid number
ok(0, ! $csr->execute, 1);
ok(0, $DBI::err == 1722);


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


# --- test plsql_errstr
ok(0, $csr = $dbh->prepare(q{
    create or replace package doit as
	  procedure filltab( stuff out tab ); asdf
    end doit;
}), 1);
my $msg = $dbh->func('plsql_errstr');
ok(0, $msg =~ /Encountered the symbol/, $msg);


    # To do
    #   test NULLs at first bind
    #   NULLS later binds.
    #   returning NULLS
    #   multiple params, mixed types and in only vs inout


$csr->finish;
$dbh->disconnect;
exit 0;
BEGIN { $tests = 28 }
# end.

