#!/usr/local/bin/perl -w

# $Id: test.pl,v 1.25 1996/10/15 02:19:14 timbo Exp $
#
# Copyright (c) 1995, Tim Bunce
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

require 'getopts.pl';

$| = 1;
print q{Oraperl test application $Revision: 1.25 $}."\n";

$SIG{__WARN__} = sub {
	($_[0] =~ /^Bad free/) ? warn "See README about Bad free() warnings!\n": warn @_;
};

$opt_d = 0;		# debug
$opt_l = 0;		# log
$opt_c = 5;		# count for loops
$opt_m = 0;		# count for mem leek test
$opt_p = 1;		# test pl/sql code
&Getopts('m:d:c:lp ') || die "Invalid options\n";

$ENV{PERL_DBI_DEBUG} = 2 if $opt_d;
$ENV{ORACLE_HOME} = '/usr/oracle' unless $ENV{ORACLE_HOME};

$dbname = $ARGV[0] || '';	# $ENV{TWO_TASK} || $ENV{ORACLE_SID} || 'crgs';
$dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

eval '$Oraperl::safe = 1'       if $] >= 5;
eval 'use Oraperl; 1' || die $@ if $] >= 5;

&ora_version;

print "\nConnecting\n",
      " to '$dbname' (from command line, else uses ORACLE_SID or TWO_TASK - recommended)\n";
print " as '$dbuser' (via ORACLE_USERID env var or default - recommend name/passwd\@dbname)\n";
printf("(ORACLE_SID='%s', TWO_TASK='%s')\n", $ENV{ORACLE_SID}||'', $ENV{TWO_TASK}||'');

{	# test connect works first
	local($l) = &ora_login($dbname, $dbuser, '');
    unless($l) {
		warn "ora_login: $ora_errno: $ora_errstr\n";
		# Try to help dumb users who don't know how to connect to oracle...
	    warn "\nHave you set the environment variable ORACLE_USERID ?\n"
			if ($ora_errno == 1017);	# ORA-01017: invalid username/password
	    warn "\nHave you included your password in ORACLE_USERID ? (e.g., 'user/passwd')\n"
			if ($ora_errno == 1017 and $dbuser !~ m:/:);
	    warn "\nHave you set the environment variable ORACLE_SID or TWO_TASK?\n"
			if ($ora_errno == 2700);	# error translating ORACLE_SID
	    warn "\nORACLE_SID or TWO_TASK possibly not right, or server not running.\n"
			if ($ora_errno == 1034);	# ORA-01034: ORACLE not available
	    warn "\nTWO_TASK possibly not set correctly right.\n"
			if ($ora_errno == 12545);
		warn "\n";
        warn "Try to connect to the database using an oracle tool like sqlplus\n";
        warn "only if that works should you suspect problems with DBD::Oracle.\n";
        warn "Try leaving dbname value empty and set dbuser to name/passwd\@dbname.\n";
		die "\nTest aborted.\n";
    }
	&ora_logoff($l)	|| warn "ora_logoff($l): $ora_errno: $ora_errstr\n";
}
$start = time;

rename("test.log","test.olog") if $opt_l;
eval 'DBI->internal->{DebugLog} = "test.log";'  if $opt_l;

&test3($opt_m) if $opt_m;

&test1();

print "\nTesting repetitive connect/open/close/disconnect:\n";
print "Expect sequence of digits, no other messages:\n";
#DBI->internal->{DebugDispatch} = 2;
foreach(1..$opt_c) { print "$_ "; &test2(); }
print "\n";

print "\nTest interaction of explicit close/logoff and implicit DESTROYs\n";
print "Expect just 'done.', no other messages:\n";
$lda2 = &ora_login($dbname, $dbuser, '');
$csr2 = &ora_open($lda2, "select 42 from dual") || die "ora_open: $ora_errno: $ora_errstr\n";
&ora_close($csr2)  || warn "ora_close($csr2): $ora_errno: $ora_errstr\n";
&ora_logoff($lda2) || warn "ora_logoff($lda2): $ora_errno: $ora_errstr\n";
print "done.\n";

&test3($opt_m) if $opt_m;

&test_plsql() if $opt_p;

$dur = time - $start;
print "\nTest complete ($dur seconds).\n";
print "If the tests above have produced the 'expected' output then they have passed.\n";

exit 0;


sub test1 {
    local($lda) = &ora_login($dbname, $dbuser, '')
			|| die "ora_login: $ora_errno: $ora_errstr\n";

    &ora_commit($lda)   || warn "ora_commit($lda): $ora_errno: $ora_errstr\n";
    &ora_rollback($lda) || warn "ora_rollback($lda): $ora_errno: $ora_errstr\n";
    &ora_autocommit($lda, 1);
    &ora_autocommit($lda, 0);

    # Test ora_do with harmless non-select statement
    &ora_do($lda, "set transaction read only ")
			|| warn "ora_do: $ora_errno: $ora_errstr\n";

    # DBI::dump_results($lda->tables());

    # $lda->debug(2);

    {
	local($csr) = &ora_open($lda,
	    "select 11*7.2	num_t,
		    SYSDATE	date_t,
		    USER	char_t,
		    NULL	null_t
	    from dual") || die "ora_open: $ora_errno: $ora_errstr\n";

	print "Fields:  ",scalar(&ora_fetch($csr)),"\n";
	die "ora_fetch in scalar context error\n" unless &ora_fetch($csr)==4;
	print "Names:   '",join("',\t'", &ora_titles($csr)),"'\n";
	print "Lengths: '",join("',\t'", &ora_lengths($csr)),"'\n";
	print "Types:   '",join("',\t'", &ora_types($csr)),"'\n";

	print "Data rows:\n";
	#$csr->debug(2);
	while(@fields = &ora_fetch($csr)) {
	    warn "ora_fetch returned .".@fields." fields instead of 4!"
		    if (@fields!=4);
	    die "Perl list/scalar context error" if @fields==1;
	    $fields[3] = "NULL" unless defined $fields[3];
	    print "    fetch: "; print "@fields\n";
	}

	&ora_close($csr) || warn "ora_close($csr): $ora_errno: $ora_errstr\n";
	print "\n";

	print "csr reassigned (forces destruction)...\n";

	#$lda->debug(2);
	$csr = &ora_open($lda,<<"") || die "ora_open: $ora_errno: $ora_errstr\n";
		select TABLE_NAME from ALL_TABLES
		where TABLE_NAME like :1 and ROWNUM < 5

	#$lda->debug(0);
	print "Fetch list of tables:\n";
#	print "BindParams error $csr->{BindParams}\n" unless $csr->{BindParams}==1;
	&ora_bind($csr, '%');

	#DBI::dump_handle($lda, "lda");
	#DBI::dump_handle($csr, "csr");

	while(@fields = &ora_fetch($csr)){
		print "Fetched: "; print "@fields\n";
	}
	warn "ora_fetch($csr): $ora_errno: $ora_errstr\n" if $ora_errno;

	print "Test ora_do with harmless non-select statement ",
			"(set transaction read only)\n";
    # example: push(@{$lda->{Handlers}}, sub { die "ora_errno=$ora_errno" } );
	print "Expect error message:\n";
	&ora_do($lda, "set transaction read only ")
		    || warn "ora_do: $ora_errno: $ora_errstr\n";

	print "csr out of scope...\n";
    }

    print "ora_logoff...\n";
    &ora_logoff($lda)   || warn "ora_logoff($lda): $ora_errno: $ora_errstr\n";

    print "lda out of scope...\n";
}


sub test2 {
    local($l) = &ora_login($dbname, $dbuser, '')
			|| die "ora_login: $ora_errno: $ora_errstr\n";
    local($c) = &ora_open($l, "select 42,42,42,42,42,42,42 from dual")
			|| die "ora_open: $ora_errno: $ora_errstr\n";
    local(@row);
    @row = &ora_fetch($c);
    &ora_close($c)	|| warn "ora_close($c):  $ora_errno: $ora_errstr\n";
    &ora_logoff($l)	|| warn "ora_logoff($l): $ora_errno: $ora_errstr\n";
}


sub test3 {
    local($count) = @_;
    local($ps) = (-d '/proc') ? "ps -p " : "ps -l";
    local($i) = 0;

    while(++$i <= $count) {
	system("echo $i; $ps$$") if (($i % 10) == 0);
	&test2();
    }
    system("echo $i; $ps$$") if (($i % 10) == 0);
}


sub test_plsql {

	print "\nTesting PL/SQL interaction.\n";

    local($l) = &ora_login($dbname, $dbuser, '')
			|| die "ora_login: $ora_errno: $ora_errstr\n";
    my $c;

    $c = &ora_open($l, q{
		begin RAISE invalid_number; end;
    });
    # Expect ORA-01722: invalid number
    die "ora_open: $ora_errstr" unless $ora_errno == 1722;

    $c = &ora_open($l, q{
		DECLARE FOO EXCEPTION;
		begin raise foo; end;
    });
    # Expect ORA-06510: PL/SQL: unhandled user-defined exception
    die "ora_open: $ora_errstr" unless $ora_errno == 6510;

    $c = &ora_open($l, q{
		begin raise_application_error(-20101,'app error'); end;
    });
    # Expect our exception number and error text
    die "ora_open: $ora_errno $ora_errstr"
	    unless $ora_errno == 20101;			# our exception number
    die "ora_open: $ora_errstr"
	    unless $ora_errstr =~ m/app error/;	# our exception text

    $c = &ora_open($l, q{
	declare err_num number; err_msg char(510);
	begin
	    err_num := :1;
	    err_msg := :2;
	    raise_application_error(-20000-err_num, 'plus '||err_msg);
	end;
    }) || die "ora_open: $ora_errstr";
    $c->execute(42,"my msg");
    # Expect our exception number and error text
    die "ora_open: $ora_errno $ora_errstr"
	    unless $ora_errno == 20042;				# our exception number
    die "ora_open: $ora_errstr"
	    unless $ora_errstr =~ m/plus my msg/;	# our exception text

    print "Testing bind_param_inout. Expect '200', '3800', '75800':\n";
    #$l->debug(2);
    #DBI->internal->{DebugDispatch} = 2;
    $c = &ora_open($l, q{
	declare bar number;
	begin bar := :1; bar := bar * 20; :1 := bar; end;
    }) || die "ora_open: $ora_errstr";
    $param = 10;
    $c->bind_param_inout(1, \$param, 100) || die "bind_param_inout $ora_errstr";
    do {
	$c->execute	|| die "execute $ora_errstr";
	print "param='$param'\n";
	$param -= 10;
    } while ($param < 70000);

    # To do
    #	test NULLs at first bind
    #	NULLS later binds.
    #	returning NULLS
    #	multiple params, mixed types and in only vs inout
    #	automatic rebind if location changes
}

# end.
