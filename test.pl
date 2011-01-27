#!/usr/local/bin/perl -w

use ExtUtils::testlib;

die "Use 'perl -Mblib test.pl' or 'make test' to run test.pl\n"
    unless "@INC" =~ /\bblib\b/;

# Copyright (c) 1995-2004, Tim Bunce
#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the Perl README file.

# XXX
# XXX  PLEASE NOTE THAT THIS CODE IS A RANDOM HOTCH-POTCH OF TESTS AND
# XXX  TEST FRAMEWORKS AND IS IN *NO WAY* A TO BE USED AS A STYLE GUIDE!
# XXX

$| = 1;

use Getopt::Long;
use Config;

my $os = $Config{osname};

GetOptions(
	'm!'	=> \my $opt_m,	# do mem leak test
	'n=i'	=> \my $opt_n,	# num loops for some tests
	'c=i'	=> \my $opt_c,	# RowCacheSize for some tests
	'f=i'	=> \my $opt_f,	# fetch test
	'p!'	=> \my $opt_p,	# perf test
) or die;
$opt_n ||= 10;

# skip this old set of half-baked oddities if ORACLE_DSN env var is set
exit 0 if $ENV{ORACLE_DSN};

$dbname = $ARGV[0] || '';	# if '' it'll use TWO_TASK/ORACLE_SID
$dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

use Oraperl;

exit test_extfetch_perf($opt_f) if $opt_f;

exit test_leak(10 * $opt_n) if $opt_m;

&ora_version;

my @data_sources = DBI->data_sources('Oracle');
print "Data sources:\n\t", join("\n\t",@data_sources),"\n";

print "Connecting\n",
      " to '$dbname' (from command line, else uses ORACLE_SID or TWO_TASK - recommended)\n";
print " as '$dbuser' (via ORACLE_USERID env var or default - recommend name/passwd\@dbname)\n";
printf("(ORACLE_SID='%s', TWO_TASK='%s')\n", $ENV{ORACLE_SID}||'', $ENV{TWO_TASK}||'');
printf("(LOCAL='%s', REMOTE='%s')\n", $ENV{LOCAL}||'', $ENV{REMOTE}||'') if $os eq 'MSWin32';

{	# test connect works first
    local($l) = &ora_login($dbname, $dbuser, '');
    unless($l) {
	$ora_errno = 0 unless defined $ora_errno;
	$ora_errstr = '' unless defined $ora_errstr;
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
        warn "\nTest aborted cannot connect.\n";
        exit 0;
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

&test_intfetch_perf() if $opt_p;

&test1();

print "\nRepetitive connect/open/close/disconnect:\n";
#print "If this test hangs then read the README.help.txt file.\n";
#print "Expect sequence of digits, no other messages:\n";
# likely to fail with: ORA-12516: TNS:listener could not find available handler with matching protocol stack (DBD ERROR: OCIServerAttach)
# in default configurations if the number of iterations is high (>~20)
my $connect_loop_start = DBI::dbi_time();
foreach(1..$opt_n) { print "$_ "; &test2(); }
my $dur = DBI::dbi_time() - $connect_loop_start;
printf "(~%.3f seconds each)\n", $dur / $opt_n;

print "test.pl complete.\n\n";

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
	    "select to_number('7.2', '9D9',
			'NLS_NUMERIC_CHARACTERS =''.,'''
		    )			num_t,
		    SYSDATE		date_t,
		    USER		char_t,
		    ROWID		rowid_t,
		    HEXTORAW('7D')      raw_t,
		    NULL		null_t
	    from dual") || die "ora_open: $ora_errno: $ora_errstr\n";
	$csr->{RaiseError} = 1;

	print "Fields:    ",scalar(&ora_fetch($csr)),"\n";
	die "ora_fetch in scalar context error" unless &ora_fetch($csr)==6;
	print "Names:     \t",join("\t", &ora_titles($csr)),"\n";
	print "Lengths:   \t",DBI::neat_list([&ora_lengths($csr)],0,"\t"),"\n";
	print "OraTypes:  \t",DBI::neat_list([&ora_types($csr)],	0,"\t"),"\n";
	print "SQLTypes:  \t",DBI::neat_list($csr->{TYPE},		0,"\t"),"\n";
	print "Scale:     \t",DBI::neat_list($csr->{SCALE},		0,"\t"),"\n";
	print "Precision: \t",DBI::neat_list($csr->{PRECISION},	0,"\t"),"\n";
	print "Nullable:  \t",DBI::neat_list($csr->{NULLABLE},	0,"\t"),"\n";
	print "Est row width:\t$csr->{ora_est_row_width}\n";
	print "Prefetch cache:   $csr->{RowsInCache}\n" if $csr->{RowsInCache};

	print "Data rows:\n";
	#$csr->debug(2);
	while(@fields = $csr->fetchrow_array) {
	    die "ora_fetch returned ".@fields." fields instead of 6!"
		    if @fields != 6;
	    die "Perl list/scalar context error" if @fields==1;
	    print "    fetch: ", DBI::neat_list(\@fields),"\n";
	}
	&ora_close($csr) || warn "ora_close($csr): $ora_errno: $ora_errstr\n";
    }
    &ora_logoff($lda)   || warn "ora_logoff($lda): $ora_errno: $ora_errstr\n";
}


sub test2 {		# also used by test_leak()
    my $execute_sth = shift;
    my $dbh = DBI->connect("dbi:Oracle:$dbname", $dbuser, '', { RaiseError=>1 });
    if ($execute_sth) {
	my $sth = $dbh->prepare("select 42,'foo',sysdate from dual where ? >= 1");
	while ($execute_sth-- > 0) {
	    $sth->execute(1);
	    my @row = $sth->fetchrow_array;
	    $sth->finish;
	}
    }
    $dbh->disconnect;
}


sub test_leak {
    local($count) = @_;
    local($ps) = (-d '/proc') ? "ps -lp " : "ps -l";
    local($i) = 0;
    my $execute_sth = 100;
    print "\nMemory leak test: (execute $execute_sth):\n";
    while(++$i <= $count) {
	&test2($execute_sth);
	system("echo $i; $ps$$") if (($i % 10) == 1);
    }
    system("echo $i; $ps$$");
    print "Done.\n\n";
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


sub test_intfetch_perf {
    print "\nTesting internal row fetch overhead.\n";
    local($lda) = &ora_login($dbname, $dbuser, '')
		    || die "ora_login: $ora_errno: $ora_errstr\n";
    DBI->trace(0);
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

sub test_extfetch_perf {
    my $max = shift;
    print "\nTesting external row fetch overhead.\n";
    my $rows = 0;
    my $dbh = DBI->connect("dbi:Oracle:$dbname", $dbuser, '', { RaiseError => 1 });
    #$dbh->trace(2);
    $dbh->{RowCacheSize} = $::opt_c if defined  $::opt_c;
    my $fields = (0) ? "*" : "object_name, status, object_type";
    my $sth = $dbh->prepare(q{
	select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	union all select all * from all_objects o1
	--, all_objects o2
	--where o1.object_id <= 400 and o2.object_id <= 400
    }, { ora_check_sql => 1 });

    require Benchmark;
    $t0 = new Benchmark;
    $sth->execute;
    $sth->trace(0);
    $sth->fetchrow_arrayref;	# fetch one before starting timer
    $td = Benchmark::timediff((new Benchmark), $t0);
    printf("Execute: ".Benchmark::timestr($td)."\n");

    print "Fetching data with RowCacheSize $dbh->{RowCacheSize}...\n";
    $t1 = new Benchmark;
    1 while $sth->fetchrow_arrayref && ++$rows < $max;
    $td = Benchmark::timediff((new Benchmark), $t1);
    printf("$rows fetches: ".Benchmark::timestr($td)."\n");
    printf("%d per clock second, %d per cpu second\n",
	    $rows/($td->real  ? $td->real  : 1),
	    $rows/($td->cpu_a ? $td->cpu_a : 1));
    my $ps = (-d '/proc') ? "ps -lp " : "ps -l";
    system("echo Process memory size; $ps$$");
    print "\n";
    $sth->finish;
    $dbh->disconnect;
    exit 1;
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
