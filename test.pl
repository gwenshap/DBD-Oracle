#!/usr/local/bin/perl -w

use ExtUtils::testlib;

die "Use 'make test' to run test.pl\n" unless "@INC" =~ /\bblib\b/;

# $Id: test.pl,v 1.30 1997/06/14 17:42:12 timbo Exp $
#
# Copyright (c) 1995, Tim Bunce
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

require 'getopts.pl';

$| = 1;
print q{Oraperl test application $Revision: 1.30 $}."\n";

$SIG{__WARN__} = sub {
	($_[0] =~ /^(Bad|Duplicate) free/)
		? warn "\n*** Read the README file about Bad free() warnings!\n": warn @_;
};

$opt_d = 0;		# debug
$opt_l = 0;		# log
$opt_n = 5;		# num of loops
$opt_m = 0;		# count for mem leek test
$opt_c = 1;		# do cache test
&Getopts('m:d:n:cl ') || die "Invalid options\n";

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
eval 'DBI->_debug_dispatch(3,"test.log");' if $opt_l;

&test3($opt_m) if $opt_m;

&test1();

print "\nTesting repetitive connect/open/close/disconnect:\n";
print "Expect sequence of digits, no other messages:\n";
#DBI->internal->{DebugDispatch} = 2;
foreach(1..$opt_n) { print "$_ "; &test2(); }
print "\n";

print "\nTest interaction of explicit close/logoff and implicit DESTROYs\n";
print "Expect just 'done.', no other messages:\n";
$lda2 = &ora_login($dbname, $dbuser, '');
$csr2 = &ora_open($lda2, "select 42 from dual") || die "ora_open: $ora_errno: $ora_errstr\n";
&ora_close($csr2)  || warn "ora_close($csr2): $ora_errno: $ora_errstr\n";
&ora_logoff($lda2) || warn "ora_logoff($lda2): $ora_errno: $ora_errstr\n";
print "done.\n";

&test3($opt_m) if $opt_m;

&test_cache() if $opt_c;

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
			|| warn "ora_do: $ora_errno: $ora_errstr";

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


sub test_cache {
    local($cache) = 5;
    print "\nTesting row cache ($cache).\n";
    local($l) = &ora_login($dbname, $dbuser, '')
		    || die "ora_login: $ora_errno: $ora_errstr\n";
    local($csr, $rows, $max);
    local($start) = time;
    foreach $max (1, 0, $cache-1, $cache, $cache+1) {
	$csr = &ora_open($l, q{
		select object_name from all_objects where rownum <= :1
	}, $cache);
	&ora_bind($csr, $max) || die $ora_errstr;
	$rows = count_fetch($csr);
	die "test_cache $rows/$max" if $rows != $max;
	&ora_bind($csr, $max+1) || die $ora_errstr;
	$rows = count_fetch($csr);
	die "test_cache $rows/$max+1" if $rows != $max+1;
    }
    # this test will only show timing improvements when
    # run over a modem link. It's primarily designed to
    # test boundary cases in the cache code.
    print "Test completed in ".(time-$start)." seconds.\n";
}
sub count_fetch {
    local($csr) = @_;
    local($rows) = 0;
    while((@row) = &ora_fetch($csr)) {
       ++$rows;
    }
    die "count_fetch $ora_errstr" if $ora_errno;
    return $rows;
}


# end.
