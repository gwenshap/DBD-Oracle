#!/usr/local/bin/perl -w

use ExtUtils::testlib;

die "Use 'make test' to run test.pl\n" unless "@INC" =~ /\bblib\b/;

# $Id: test.pl,v 1.33 1998/12/16 00:19:34 timbo Exp $
#
# Copyright (c) 1995-1998, Tim Bunce
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

# XXX
# XXX  PLEASE NOTE THAT THIS CODE IS A RANDOM HOTCH-POTCH OF TESTS AND
# XXX  TEST FRAMEWORKS AND IS IN *NO WAY* A TO BE USED AS A STYLE GUIDE!
# XXX

require 'getopts.pl';

$| = 1;
print q{Oraperl test application $Revision: 1.33 $}."\n";

$SIG{__WARN__} = sub {
	($_[0] =~ /^(Bad|Duplicate) free/)
		? warn "\n*** Read the README file about Bad free() warnings!\n": warn @_;
};

use Config;
my $os = $Config{osname};
$opt_d = 0;		# debug
$opt_l = 0;		# log
$opt_n = 5;		# num of loops
$opt_m = 0;		# count for mem leek test
$opt_c = 1;		# do cache test
$opt_p = 1;		# do perf test
&Getopts('m:d:n:clp ') || die "Invalid options\n";

$ENV{PERL_DBI_DEBUG} = 2 if $opt_d;
$ENV{ORACLE_HOME} = '/usr/oracle' unless $ENV{ORACLE_HOME};

$dbname = $ARGV[0] || '';	# if '' it'll use TWO_TASK/ORACLE_SID
$dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

eval 'use Oraperl; 1' || die $@ if $] >= 5;

&ora_version;

my @data_sources = DBI->data_sources('Oracle');
print "Data sources:\n\t", join("\n\t",@data_sources),"\n\n";

print "\nConnecting\n",
      " to '$dbname' (from command line, else uses ORACLE_SID or TWO_TASK - recommended)\n";
print " as '$dbuser' (via ORACLE_USERID env var or default - recommend name/passwd\@dbname)\n";
printf("(ORACLE_SID='%s', TWO_TASK='%s')\n", $ENV{ORACLE_SID}||'', $ENV{TWO_TASK}||'');
printf("(LOCAL='%s', REMOTE='%s')\n", $ENV{LOCAL}||'', $ENV{REMOTE}||'') if $os eq 'MSWin32';


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
        warn "Generally set TWO_TASK or ORACLE_SID but not both at the same time.\n";
        warn "Try to connect to the database using an oracle tool like sqlplus\n";
        warn "only if that works should you suspect problems with DBD::Oracle.\n";
        warn "Try leaving dbname value empty and set dbuser to name/passwd\@dbname.\n";
	die "\nTest aborted.\n";
    }
    if ($os ne 'MSWin32' and $os ne 'VMS') {
	my $backtick = `sleep 1; echo Backticks OK`;
	unless ($backtick) {	 # $! == Interrupted system call
	    print "Warning: Oracle's SIGCHLD signal handler breaks perl ",
		  "`backticks` commands: $!\n(d_sigaction=$Config{d_sigaction})\n";
	}
    }
    #test_bind_csr($l);
    #test_auto_reprepare($l);
    &ora_logoff($l)	|| warn "ora_logoff($l): $ora_errno: $ora_errstr\n";
}
$start = time;

rename("test.log","test.olog") if $opt_l;
eval 'DBI->_debug_dispatch(3,"test.log");' if $opt_l;

&test_fetch_perf() if $opt_p;

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
	#$lda->trace(2);
	local($csr) = &ora_open($lda,
	    "select 11*7.2	num_t,
		    SYSDATE	date_t,
		    USER	char_t,
		    ROWID	rowid_t,
		    NULL	null_t
	    from dual") || die "ora_open: $ora_errno: $ora_errstr\n";
	$csr->{RaiseError} = 1;

	print "Fields:    ",scalar(&ora_fetch($csr)),"\n";
	die "ora_fetch in scalar context error" unless &ora_fetch($csr)==5;
	print "Names:     ",DBI::neat_list([&ora_titles($csr)],	0,"\t"),"\n";
	print "Lengths:   ",DBI::neat_list([&ora_lengths($csr)],0,"\t"),"\n";
	print "OraTypes:  ",DBI::neat_list([&ora_types($csr)],	0,"\t"),"\n";
	print "SQLTypes:  ",DBI::neat_list($csr->{TYPE},		0,"\t"),"\n";
	print "Scale:     ",DBI::neat_list($csr->{SCALE},		0,"\t"),"\n";
	print "Precision: ",DBI::neat_list($csr->{PRECISION},	0,"\t"),"\n";
	print "Nullable:  ",DBI::neat_list($csr->{NULLABLE},	0,"\t"),"\n";
	print "Est row width:    $csr->{ora_est_row_width}\n";
	print "Prefetch cache:   $csr->{RowsInCache}\n" if $csr->{RowsInCache};

	print "Data rows:\n";
	#$csr->debug(2);
	while(@fields = $csr->fetchrow_array) {
	    die "ora_fetch returned ".@fields." fields instead of 5!"
		    if @fields != 5;
	    die "Perl list/scalar context error" if @fields==1;
	    print "    fetch: ", DBI::neat_list(\@fields),"\n";
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
	print "Expect an 'ORA-01453' error message:\n";
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
    #$l->trace(3);
    foreach $max (1, 0, $cache-1, $cache, $cache+1) {
	$csr = &ora_open($l, q{
		select object_name, rownum from all_objects where rownum <= :1
	}, $cache);
	&ora_bind($csr, $max) || die $ora_errstr;
	$rows = count_fetch($csr);
	die "test_cache $rows/$max" if $rows != $max;
	&ora_bind($csr, $max+2) || die $ora_errstr;
	$rows = count_fetch($csr);
	die "test_cache $rows/$max+2" if $rows != $max+2;
    }
    # this test will only show timing improvements when
    # run over a modem link. It's primarily designed to
    # test boundary cases in the cache code.
    print "Test completed in ".(time-$start)." seconds.\n";
}
sub count_fetch {
    local($csr) = @_;
    local($rows) = 0;
   # while((@row) = &ora_fetch($csr)) {
    while((@row) = $csr->fetchrow_array) {
       ++$rows;
    }
    die "count_fetch $ora_errstr" if $ora_errno;
    return $rows;
}


sub test_fetch_perf {
    print "\nTesting internal row fetch overhead.\n";
    local($lda) = &ora_login($dbname, $dbuser, '')
		    || die "ora_login: $ora_errno: $ora_errstr\n";
    $lda->trace(0);
    local($csr) = &ora_open($lda,"select 0,1,2,3,4,5,6,7,8,9 from dual");
    local($max) = 50000;
    $csr->{ora_fetchtest} = $max;
    require Benchmark;
    $t0 = new Benchmark;
    1 while $csr->fetchrow_arrayref;
    $td = Benchmark::timediff((new Benchmark), $t0);
    $csr->{ora_fetchtest} = 0;
    printf("$max fetches: ".Benchmark::timestr($td)."\n");
    printf("%d per clock second, %d per cpu second\n\n",
	    $max/($td->real  ? $td->real  : 1),
	    $max/($td->cpu_a ? $td->cpu_a : 1));
}


sub test_bind_csr {
    local($lda) = @_;
$lda->{RaiseError} =1;
$lda->trace(2);
my $out_csr = $lda->prepare(q{select 42 from dual}); # sacrificial csr XXX
$csr = $lda->prepare(q{
    begin
    OPEN :csr_var FOR select * from all_tables;
    end;
});
$csr->bind_param_inout(':csr_var', \$out_csr, 100, { ora_type => 102 });
$csr->execute();
# at this point $out_csr should be a handle on a new oracle cursor
@row = $out_csr->fetchrow_array;

    exit 1;
}

sub test_auto_reprepare {
    local($dbh) = @_;
    $dbh->do(q{drop table timbo});
    $dbh->{RaiseError} =1;
    #$dbh->trace(2);
    $dbh->do(q{create table timbo ( foo integer)});
    $dbh->do(q{insert into timbo values (91)});
    $dbh->do(q{insert into timbo values (92)});
    $dbh->do(q{insert into timbo values (93)});
    $dbh->commit;
	$Oraperl::ora_cache = $Oraperl::ora_cache = 1;
    my $sth = $dbh->prepare(q{select * from timbo for update});
    $sth->execute; $sth->dump_results;
    $sth->execute;
    print $sth->fetchrow_array,"\n";
    $dbh->commit;
    print $sth->fetchrow_array,"\n";
    $dbh->do(q{drop table timbo});
    exit 1;
}

# end.
