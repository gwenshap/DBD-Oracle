
#   $Id: Oracle.pm,v 1.59 1998/12/02 02:48:32 timbo Exp $
#
#   Copyright (c) 1994,1995,1996,1997,1998 Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file,
#   with the exception that it cannot be placed on a CD-ROM or similar media
#   for commercial distribution without the prior approval of the author.

require 5.002;

$DBD::Oracle::VERSION = '0.54_91';

my $ORACLE_ENV  = ($^O eq 'VMS') ? 'ORA_ROOT' : 'ORACLE_HOME';

{
    package DBD::Oracle;

    use DBI ();
    use DynaLoader ();
    use Exporter ();
    @ISA = qw(DynaLoader Exporter);

    my $Revision = substr(q$Revision: 1.59 $, 10);

    require_version DBI 0.92;

    bootstrap DBD::Oracle $VERSION;

    $err = 0;		# holds error code   for DBI::err    (XXX SHARED!)
    $errstr = "";	# holds error string for DBI::errstr (XXX SHARED!)
    $drh = undef;	# holds driver handle once initialised

    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;

	$class .= "::dr";

	# not a 'my' since we use it above to prevent multiple drivers

	$drh = DBI::_new_drh($class, {
	    'Name' => 'Oracle',
	    'Version' => $VERSION,
	    'Err'    => \$DBD::Oracle::err,
	    'Errstr' => \$DBD::Oracle::errstr,
	    'Attribution' => 'Oracle DBD by Tim Bunce',
	    });

	$drh;
    }


    END {
	# Used to silence 'Bad free() ...' warnings caused by bugs in Oracle's code
	# being detected by Perl's malloc.
	$ENV{PERL_BADFREE} = 0;
    }

    1;
}


{   package DBD::Oracle::dr; # ====== DRIVER ======
    use strict;

    my %dbnames = ();	# holds list of known databases (oratab + tnsnames)

    sub load_dbnames {
	my ($drh) = @_;
	my $debug = $drh->debug;
	my $oracle_home = $ENV{$ORACLE_ENV} || '';
	local *FH;
	my $d;

	# get list of 'local' database SIDs from oratab
	foreach $d (qw(/etc /var/opt/oracle), $ENV{TNS_ADMIN}) {
	    next unless defined $d;
	    next unless open(FH, "<$d/oratab");
	    warn "Loading $d/oratab\n" if $debug;
	    while (<FH>) {
		next unless m/^\s*(\w+)\s*:\s*(.*?)\s*:/;
		$dbnames{$1} = $2;	# store ORACLE_HOME value
		warn "Found $1 \@ $2.\n" if $debug;
	    }
	    close FH;
	    last;
	}

	# get list of 'remote' database connection identifiers
	foreach $d ($ENV{TNS_ADMIN}, "$oracle_home/network/admin", '/var/opt/oracle') {
	    next unless defined $d;
	    next unless open(FH, "<$d/tnsnames.ora");
	    warn "Loading $d/tnsnames.ora\n" if $debug;
	    while (<FH>) {
		next unless m/^\s*([-\w\.]+)\s*=/;
		my $name = $1;
		warn "Found $name. ".($dbnames{$name} ? "(oratab entry overridden)" : "")."\n"
		    if $debug;
		$dbnames{$name} = 0; # exists but false (to distinguish from oratab)
	    }
	    close FH;
	    last;
	}

	eval q{	# XXX experimental, will probably change
	    warn "Fetching ORACLE_SID from Registry.\n" if $debug;
	    require Tie::Registry;
	    $Tie::Registry::Registry->Delimeter("/");
	    my $hkey= $Tie::Registry::Registry->{"LMachine/Software/Oracle/"};
	    my $sid = $hkey->{ORACLE_SID};
	    my $home= $hkey->{ORACLE_HOME} || $ENV{ORACLE_HOME};
	    $dbnames{$sid} = $home if $sid and $home;
	    warn "Found $sid \@ $home.\n" if $debug;
	} if ($^O eq "MSWin32");

	$dbnames{0} = 1;	# mark as loaded (even if empty)
    }

    sub data_sources {
	my $drh = shift;
	load_dbnames($drh) unless %dbnames;
	my @names = sort  keys %dbnames;
	my @sources = map { $_ ? ("dbi:Oracle:$_") : () } @names;
	return @sources;
    }


    sub connect {
	my($drh, $dbname, $user, $auth)= @_;

	if ($dbname){	# application is asking for specific database

	    # We can use the 'user/passwd@machine' form of user.
	    # $TWO_TASK and $ORACLE_SID will be ignored in that case.

	    if ($dbname =~ /@/){	# Implies an Sql*NET connection

		$user = "$user/$auth$dbname";
		$auth = "";
	    }
	    elsif ($dbname =~ /:/){	# Implies an Sql*NET connection

		$user = "$user/$auth".'@'.$dbname;
		$auth = "";
	    }
	    else {

		# Is this a NON-Sql*NET connection (ORACLE_SID)?
		# Or is it an alias for an Sql*NET connection (TWO_TASK)?
		# Sadly the 'user/passwd@machine' form only works
		# for Sql*NET connections.

		load_dbnames($drh) unless %dbnames;

		if (exists $dbnames{$dbname}) {	# known name
		    my $dbhome = $dbnames{$dbname};	# local=>ENV, remote=>0
		    if ($dbhome) {
			warn "Changing $ORACLE_ENV for $dbname to $dbhome (to match oratab entry)"
			    if ($ENV{$ORACLE_ENV} and $dbhome ne $ENV{$ORACLE_ENV});
			$ENV{ORACLE_SID}  = $dbname;
			$ENV{$ORACLE_ENV} = $dbhome;
			delete $ENV{TWO_TASK};
		    }
		    else {
			$user .= '@'.$dbname;	# it's a known TNS alias
		    }
		}
		else {
		    $user .= '@'.$dbname;	# assume it's a TNS alias
		}
	    }
	}

	warn "$ORACLE_ENV not set!\n" unless $ENV{$ORACLE_ENV};

	# create a 'blank' dbh

	my $dbh = DBI::_new_dbh($drh, {
	    'Name' => $dbname,
	    'USER' => $user, 'CURRENT_USER' => $user,
	    });

	# Call Oracle OCI orlon func in Oracle.xs file
	# and populate internal handle data.
	DBD::Oracle::db::_login($dbh, $dbname, $user, $auth)
	    or return undef;

	$dbh;
    }

}


{   package DBD::Oracle::db; # ====== DATABASE ======
    use strict;

    sub prepare {
	my($dbh, $statement, @attribs)= @_;

	# create a 'blank' sth

	my $sth = DBI::_new_sth($dbh, {
	    'Statement' => $statement,
	    });

	# Call Oracle OCI oparse func in Oracle.xs file.
	# (This will actually also call oopen for you.)
	# and populate internal handle data.

	DBD::Oracle::st::_prepare($sth, $statement, @attribs)
	    or return undef;

	$sth;
    }


    sub ping {
	my($dbh) = @_;
	# we know that Oracle 7 prepare does a describe so this will
	# actually talk to the server and is this a valid and cheap test.
	my $sth =  $dbh->prepare("select SYSDATE from DUAL");
	# But Oracle 8 doesn't talk to server unless we describe the query
	return 1 if $sth && $sth->{NUM_OF_FIELDS};
	return 0;
    }


    sub table_info {
	my($dbh) = @_;		# XXX add qualification
	# XXX add knowledge of public synonmys views etc
	# The SYS/SYSTEM should probably be a decode that
	# prepends 'SYSTEM ' to TABLE_TYPE.
	my $sth = $dbh->prepare("select
		NULL		TABLE_QUALIFIER,
		at.OWNER	TABLE_OWNER,
		at.TABLE_NAME,
		tc.TABLE_TYPE,
		tc.COMMENTS	REMARKS
	    from ALL_TABLES at, ALL_TAB_COMMENTS tc
	    where at.OWNER = tc.OWNER
	    and at.TABLE_NAME = tc.TABLE_NAME
	    and at.OWNER <> 'SYS' and at.OWNER <> 'SYSTEM'
	    order by tc.TABLE_TYPE, at.OWNER, at.TABLE_NAME
	") or return undef;
	$sth->execute or return undef;
	$sth;
    }

    sub type_info_all {
	my ($dbh) = @_;
	my $names = {
          TYPE_NAME		=> 0,
          DATA_TYPE		=> 1,
          COLUMN_SIZE		=> 2,
          LITERAL_PREFIX	=> 3,
          LITERAL_SUFFIX	=> 4,
          CREATE_PARAMS		=> 5,
          NULLABLE		=> 6,
          CASE_SENSITIVE	=> 7,
          SEARCHABLE		=> 8,
          UNSIGNED_ATTRIBUTE	=> 9,
          FIXED_PREC_SCALE	=>10,
          AUTO_UNIQUE_VALUE	=>11,
          LOCAL_TYPE_NAME	=>12,
          MINIMUM_SCALE		=>13,
          MAXIMUM_SCALE		=>14,
        };
	# Based on the values from Oracle 8.0.4 ODBC driver
	my $ti = [
	  $names,
          [ 'LONG RAW', -4, '2147483647', '\'', '\'', undef, 1, '0', '0',
            undef, '0', undef, undef, undef, undef
          ],
          [ 'RAW', -3, 255, '\'', '\'', 'max length', 1, '0', 3,
            undef, '0', undef, undef, undef, undef
          ],
          [ 'LONG', -1, '2147483647', '\'', '\'', undef, 1, 1, '0',
            undef, '0', undef, undef, undef, undef
          ],
          [ 'CHAR', 1, 255, '\'', '\'', 'max length', 1, 1, 3,
            undef, '0', '0', undef, undef, undef
          ],
          [ 'NUMBER', 3, 38, undef, undef, 'precision,scale', 1, '0', 3,
            '0', '0', '0', undef, '0', 38
          ],
          [ 'DOUBLE', 8, 15, undef, undef, undef, 1, '0', 3,
            '0', '0', '0', undef, undef, undef
          ],
          [ 'DATE', 11, 19, '\'', '\'', undef, 1, '0', 3,
            undef, '0', '0', undef, '0', '0'
          ],
          [ 'VARCHAR2', 12, 2000, '\'', '\'', 'max length', 1, 1, 3,
            undef, '0', '0', undef, undef, undef
          ]
        ];
	return $ti;
    }

    sub plsql_errstr {
	# original version thanks to Bob Menteer
	my $sth = shift->prepare_cached(q{
	    select line,position,text from user_errors order by sequence
	});
	return undef unless $sth;
	$sth->execute or return undef;
	my (@msg, $line,$pos,$text);
	while(($line,$pos,$text) = $sth->fetchrow){
	    push @msg, "Error in PL/SQL block" unless @msg;
	    push @msg, "$line.$pos: $text";
	}
	join("\n", @msg);
    }

    #
    # note, dbms_output must be enabled prior to usage
    #
    sub dbms_output_enable {
	my ($dbh, $buffersize) = @_;
	$buffersize ||= 20000;	# use oracle 7.x default
	$dbh->do("begin dbms_output.enable(:1); end;", undef, $buffersize);
    }

    sub dbms_output_get {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached("begin dbms_output.get_line(:1, :2); end;")
		or return;
	my ($line, $status, @lines);
	# line can be greater that 255 (e.g. 7 byte date is expanded on output)
	$sth->bind_param_inout(1, \$line,  400);
	$sth->bind_param_inout(2, \$status, 20);
	if (!wantarray) {
	    $sth->execute or return undef;
	    return $line if $status == 0;
	    return undef;
	}
	push @lines, $line while($sth->execute && $status==0);
	return @lines;
    }

    sub dbms_output_put {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached("begin dbms_output.put_line(:1); end;")
		or return;
	my $line;
	foreach $line (@_) {
	    $sth->execute($line) or return;
	}
	return 1;
    }

}   # end of package DBD::Oracle::db


{   package DBD::Oracle::st; # ====== STATEMENT ======

    # all done in XS
}

1;

__END__

=head1 NAME

DBD::Oracle - Oracle database driver for the DBI module

=head1 SYNOPSIS

  use DBI;

  $dbh = DBI->connect("dbi:Oracle:", $user, $passwd);

  # See the DBI module documentation for full details

=head1 DESCRIPTION

DBD::Oracle is a Perl module which works with the DBI module to provide
access to Oracle databases.

=head1 CONNECTING TO ORACLE

This is a topic which often causes problems. Mainly due to Oracle's many
and sometimes complex ways of specifying and connecting to databases.
(James Taylor and Lane Sharman have contributed much of the text in
this section.)

=head2 Oracle environment variables

Oracle typically uses two environment variables to specify default
connections: ORACLE_SID and TWO_TASK.

ORACLE_SID is really unnecessary to set since TWO_TASK provides the
same functionality in addition to allowing remote connections.

  % setenv TWO_TASK T:hostname:ORACLE_SID            # for csh shell
  $ TWO_TASK=T:hostname:ORACLE_SID export TWO_TASK   # for sh shell

  % sqlplus username/password

Note that if you have *both* local and remote databases, and you
have ORACLE_SID *and* TWO_TASK set, and you don't specify a fully
qualified connect string on the command line, TWO_TASK takes precedence
over ORACLE_SID (i.e. you get connected to remote system).

  TWO_TASK=P:sid

will use the pipe driver for local connections using SQL*Net v1.

  TWO_TASK=T:machine:sid

will use TCP/IP (or D for DECNET, etc.) for remote SQL*Net v1 connection.

  TWO_TASK=dbname

will use the info stored in the SQL*Net v2 F<tnsnames.ora>
configuration file for local or remote connections.

The ORACLE_HOME environment variable should be set correctly. It can be
left unset if you aren't using any of Oracle's executables, but it is
not recommended and error messages may not display.

Discouraging the use of ORACLE_SID makes it easier on the users to see
what is going on. (It's unfortunate that TWO_TASK couldn't be renamed,
since it makes no sense to the end user, and doesn't have the ORACLE
prefix).

=head2 Using DBD::Oracle

Below are various ways of connecting to an oracle database using
SQL*Net 1.x and SQL*Net 2.x.  "Machine" is the computer the database is
running on, "SID" is the SID of the database, "DB" is the SQL*Net 2.x
connection descriptor for the database.

  BEGIN { 
     $ENV{ORACLE_HOME} = '/home/oracle/product/7.x.x';
     $ENV{TWO_TASK}    = 'DB'; 
  }
  $dbh = DBI->connect('dbi:Oracle:','scott', 'tiger');
  #  - or -
  $dbh = DBI->connect('dbi:Oracle:','scott/tiger');

works for SQL*Net 2.x, so does

  $ENV{TWO_TASK}    = 'T:Machine:SID';

for SQL*Net 1.x connections.  For local connections you can use the
pipe driver:

  $ENV{TWO_TASK}    = 'P:SID';

Here are some variations (not setting TWO_TASK)

  $dbh = DBI->connect('dbi:Oracle:T:Machine:SID','username','password')

  $dbh = DBI->connect('dbi:Oracle:','username@T:Machine:SID','password')

  $dbh = DBI->connect('dbi:Oracle:','username@DB','password')

  $dbh = DBI->connect('dbi:Oracle:DB','username','password')

  $dbh = DBI->connect('dbi:Oracle:DB','username/password','')

  $dbh = DBI->connect('dbi:Oracle:', q{scott/tiger@(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST= foobar)(PORT=1521))
  (CONNECT_DATA=(SID=foobarSID)))}, "")

If you are having problems with login taking a long time (>10 secs say)
then you might have tripped up on an Oracle bug. Yoy can try using one
of the ...@DB variants as a workaround. E.g.,

  $dbh = DBI->connect('','username/password@DB','');

On the other hand, that may cause you to trip up on another Oracle bug
that causes alternating connection attempts to fail! (In reality only
a small proportion of people experience these problems.)


=head2 Optimizing Oracle's listner

[By Lane Sharman <lane@bienlogic.com>] I spent a LOT of time optimizing
listener.ora and I am including it here for anyone to benefit from. My
connections over tnslistener on the same humble Netra 1 take an average
of 10-20 millies according to tnsping. If anyone knows how to make it
better, please let me know!

 LISTENER =
  (ADDRESS_LIST =
        (ADDRESS = 
          (PROTOCOL = TCP)
          (Host = aa.bbb.cc.d)
          (Port = 1521)
					(QUEUESIZE=10)
        )
  )

 STARTUP_WAIT_TIME_LISTENER = 0
 CONNECT_TIMEOUT_LISTENER = 10
 TRACE_LEVEL_LISTENER = OFF
 SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (SID_NAME = xxxx)
      (ORACLE_HOME = /xxx/local/oracle7-3)
			(PRESPAWN_MAX = 40)
			(PRESPAWN_LIST=
				(PRESPAWN_DESC=(PROTOCOL=tcp) (POOL_SIZE=40) (TIMEOUT=120))
			)
    )
  )

1) When the application is co-located on the host AND there is no need for
outside SQLNet connectivity, stop the listener. You do not need it. Get
your application/cgi/whatever working using pipes and shared memory. I am
convinced that this is one of the connection bugs (sockets over the same
machine). Note the $ENV{ORAPIPES} env var.  The essential code to do
this at the end of this section.

2) Be careful in how you implement the multi-threaded server. Currently I
am not using it in the initxxxx.ora file but will be doing some more testing.

3) Be sure to create user rollback segments and use them; do not use the
system rollback segments; however, you must also create a small rollback
space for the system as well.

5) Use large tuning settings and get lots of RAM. Check out all the
parameters you can set in v$parameters because there are quite a few not
documented you may to set in your initxxx.ora file. 

6) Use svrmgrl to control oracle from the command line. Write lots of small
SQL scripts to get at V$ info.

  use DBI;
  # Environmental variables used by Oracle 
  $ENV{ORACLE_SID}   = "xxx";
  $ENV{ORACLE_HOME}  = "/opt/oracle7";
  $ENV{EPC_DISABLED} = "TRUE";
  $ENV{ORAPIPES} = "V2";
  my $dbname = "xxx";
  my $dbuser = "xxx";
  my $dbpass = "xxx";
  my $dbh = DBI->connect("dbi:Oracle:$dbname", $dbuser, $dbpass)
             || die "Unale to connect to $dbname: $DBI::errstr\n";

=head2 Oracle utilities

If you are still having problems connecting then the Oracle adapters
utility may offer some help. Run these two commands:

  $ORACLE_HOME/bin/adapters
  $ORACLE_HOME/bin/adapters $ORACLE_HOME/bin/sqlplus

and check the output. The "Protocol Adapters" section should be the
same.  It should include at least "IPC Protocol Adapter" and "TCP/IP
Protocol Adapter".

If it generates any errors which look relevant then please talk to yor
Oracle technical support (and not the dbi-users mailing list). Thanks.
Thanks to Mark Dedlow for this information.

=head2 International NLS / 8-bit text issues

If 8-bit text is returned as '?' characters or can't be inserted
make sure the following environment vaiables are set correctly:
    NLS_LANG, ORA_NLS, ORA_NLS32
Thanks to Robin Langdon <robin@igis.se> for this information.
Example:
   $ENV{NLS_LANG}  = "american_america.we8iso8859p1";
   $ENV{ORA_NLS}   = "/home/oracle/ocommon/nls/admin/data";
   $ENV{ORA_NLS32} = "/home/oracle/ocommon/nls/admin/data";

Also From: Yngvi Thor Sigurjonsson <yngvi@hagkaup.is>
If you are using 8-bit characters and "export" for backups make sure
that you have NLS_LANG set when export is run.  Otherwise you might get
unusable backups with ? replacing all your beloved characters. We were
lucky once when we noticed that our exports were damaged before
disaster struck.

Remember that the database has to be created with an 8-bit character set.

Also note that the NLS files $ORACLE_HOME/ocommon/nls/admin/data
changed extension (from .d to .nlb) between 7.2.3 and 7.3.2.


=head1 PL/SQL Examples

These PL/SQL examples come from: Eric Bartley <bartley@cc.purdue.edu>.

  # we assume this package already exists
  my $plsql = q{

    CREATE OR REPLACE PACKAGE plsql_example
    IS
      PROCEDURE proc_np;
   
      PROCEDURE proc_in (
          err_code IN NUMBER
      );
   
      PROCEDURE proc_in_inout (
          test_num IN NUMBER,
          is_odd IN OUT NUMBER
      );
   
      FUNCTION func_np
        RETURN VARCHAR2;
   
    END plsql_example;
  
    CREATE OR REPLACE PACKAGE BODY plsql_example
    IS
      PROCEDURE proc_np
      IS
        whoami VARCHAR2(20) := NULL;
      BEGIN
        SELECT USER INTO whoami FROM DUAL;
      END;
   
      PROCEDURE proc_in (
        err_code IN NUMBER
      )
      IS
      BEGIN
        RAISE_APPLICATION_ERROR(err_code, 'This is a test.');
      END;
   
      PROCEDURE proc_in_inout (
        test_num IN NUMBER,
        is_odd IN OUT NUMBER
      )
      IS
      BEGIN
        is_odd := MOD(test_num, 2);
      END;
   
      FUNCTION func_np
        RETURN VARCHAR2
      IS
        ret_val VARCHAR2(20);
      BEGIN
        SELECT USER INTO ret_val FROM DUAL;
        RETURN ret_val;
      END;
   
    END plsql_example;
  };
  
  use DBI;

  my($db, $csr, $ret_val);
  
  $db = DBI->connect('dbi:Oracle:database','user','password')
        or die "Unable to connect: $DBI::errstr";
  
  # So we don't have to check every DBI call we set RaiseError.
  # See the DBI docs now if you're not familiar with RaiseError.
  $db->{RaiseError} = 1;
  
  # Example 1
  #
  # Calling a PLSQL procedure that takes no parameters. This shows you the
  # basic's of what you need to execute a PLSQL procedure. Just wrap your
  # procedure call in a BEGIN END; block just like you'd do in SQL*Plus.
  # 
  # p.s. If you've used SQL*Plus's exec command all it does is wrap the
  #      command in a BEGIN END; block for you.
  
  $csr = $db->prepare(q{
    BEGIN
      PLSQL_EXAMPLE.PROC_NP;
    END;
  });
  $csr->execute;
  
  
  # Example 2
  #
  # Now we call a procedure that has 1 IN parameter. Here we use bind_param
  # to bind out parameter to the prepared statement just like you might
  # do for an INSERT, UPDATE, DELETE, or SELECT statement.
  #
  # I could have used positional placeholders (e.g. :1, :2, etc.) or
  # ODBC style placeholders (e.g. ?), but I prefer Oracle's named
  # placeholders (but few DBI drivers support them so they're not portable).

  my $err_code = -20001;
  
  $csr = $db->prepare(q{
  	BEGIN
  	    PLSQL_EXAMPLE.PROC_IN(:err_code);
  	END;
  });
  
  $csr->bind_param(":err_code", $err_code);

  # PROC_IN will RAISE_APPLICATION_ERROR which will cause the execute to 'fail'.
  # Because we set RaiseError, the DBI will croak (die) so we catch that with eval.
  eval {
    $csr->execute;
  };
  print 'After proc_in: $@=',"'$@', errstr=$DBI::errstr, ret_val=$ret_val\n";
  
  
  # Example 3
  #
  # Building on the last example, I've added 1 IN OUT parameter. We still
  # use a placeholders in the call to prepare, the difference is that
  # we now call bind_param_inout to bind the value to the place holder.
  #
  # Note that the third parameter to bind_param_inout is the maximum size
  # of the variable. You normally make this slightly larger than necessary.
  # But note that the perl variable will have that much memory assigned to
  # it even if the actual value returned is shorter.

  my $test_num = 5;
  my $is_odd;
  
  $csr = $db->prepare(q{
  	BEGIN
  	    PLSQL_EXAMPLE.PROC_IN_INOUT(:test_num, :is_odd);
  	END;
  });
  
  # The value of $test_num is _copied_ here
  $csr->bind_param(":test_num", $test_num);

  $csr->bind_param_inout(":is_odd", \$is_odd, 1);

  # The execute will automagically update the value of $is_odd
  $csr->execute;
  
  print "$test_num is ", ($is_odd) ? "odd - ok" : "even - error!", "\n";
  

  # Example 4
  #
  # What about the return value of a PLSQL function? Well treat it the same
  # as you would a call to a function from SQL*Plus. We add a placeholder
  # for the return value and bind it with a call to bind_param_inout so
  # we can access it's value after execute.

  my $whoami = "";
  
  $csr = $db->prepare(q{
  	BEGIN
  	    :whoami := PLSQL_EXAMPLE.FUNC_NP;
  	END;
  });
  
  $csr->bind_param_inout(":whoami", \$whoami, 20);
  $csr->execute;
  print "Your database user name is $whoami\n";
  
  $db->disconnect;

You can find more examples in the t/plsql.t file in the DBD::Oracle
source directory.


=head1 Oracle on Linix

To join the oracle-on-linux mailing list, see:

  http://www.datamgmt.com/maillist.html
  http://www.eGroups.com/list/oracle-on-linux
  mailto:oracle-on-linux-subscribe@egroups.com     

=head1 Commercial Oracle Tools

Assorted tools and references for general information. No recommendation implied.

PL/Vision from RevealNet and Steven Feuerstein.

Platinum Technology: http://www.platinum.com/products/oracle.htm

SoftTree Technologies: http://www.SoftTreeTech.com

"Q" from Savant Corporation.

http://www.databasegroup.com


=head1 SEE ALSO

L<DBI>

Linux uses should read:

  http://www.wmd.de/wmd/staff/pauck/misc/oracle_on_linux.html

=head1 AUTHOR

DBD::Oracle by Tim Bunce. DBI by Tim Bunce.

=head1 COPYRIGHT

The DBD::Oracle module is Copyright (c) 1995,1996,1997,1998 Tim Bunce. England.
The DBD::Oracle module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself with the exception that it
cannot be placed on a CD-ROM or similar media for commercial distribution
without the prior approval of the author.

=head1 ACKNOWLEDGEMENTS

See also L<DBI/ACKNOWLEDGEMENTS>.

=cut
