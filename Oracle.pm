#   $Id: Oracle.pm,v 1.45 1997/06/20 21:18:11 timbo Exp $
#
#   Copyright (c) 1994,1995,1996,1997 Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file,
#   with the exception that it cannot be placed on a CD-ROM or similar media
#   for commercial distribution without the prior approval of the author.

require 5.002;

my $ORACLE_ENV  = ($^O eq 'VMS') ? 'ORACLE_ROOT' : 'ORACLE_HOME';
my $oracle_home = $ENV{$ORACLE_ENV};

{
    package DBD::Oracle;

    use DBI ();
    use DynaLoader ();
    @ISA = qw(DynaLoader);

    $VERSION = '0.46';
    my $Revision = substr(q$Revision: 1.45 $, 10);

    require_version DBI 0.84;

    bootstrap DBD::Oracle $VERSION;

    $err = 0;		# holds error code   for DBI::err
    $errstr = "";	# holds error string for DBI::errstr
    $drh = undef;	# holds driver handle once initialised
    %oratab = ();	# holds list of oratab databases (e.g., local)

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

    sub errstr {
	return $DBD::Oracle::errstr;
    }

    sub load_oratab {		# get list of 'local' databases
	my($drh) = @_;
	my $debug = $drh->debug;
	foreach(qw(/etc /var/opt/oracle), $ENV{TNS_ADMIN}) {
		next unless defined $_;
	    warn "Checking for $_/oratab\n" if $debug;
	    next unless open(ORATAB, "<$_/oratab");
	    while(<ORATAB>) {
		next unless m/^(\w+)\s*:\s*(.*?)\s*:/;
		warn "Duplicate SID $1 in $_/oratab" if $DBD::Oracle::oratab{$1};
		$DBD::Oracle::oratab{$1} = $2;	# store ORACLE_HOME value
		warn "$DBD::Oracle::oratab{$1} = $_" if $debug;
	    }
	    close(ORATAB);
	    last;
       }
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

		load_oratab($drh) unless %DBD::Oracle::oratab;

		my $orahome = $DBD::Oracle::oratab{$dbname};
		if ($orahome) { # is in oratab == is local
		    warn "Changing $ORACLE_ENV for $dbname"
			if ($ENV{$ORACLE_ENV} and $orahome ne $ENV{$ORACLE_ENV});
		    $ENV{$ORACLE_ENV} = $orahome;
		    $ENV{ORACLE_SID}  = $dbname;
		    delete $ENV{TWO_TASK};
		}
		else {
		    $user .= '@'.$dbname;	# assume it's an alias
		}
	    }
	}

	unless($ENV{$ORACLE_ENV}) {	# last chance...
	    $ENV{$ORACLE_ENV} = $oracle_home if $oracle_home;
	    my $msg = ($oracle_home) ? "set to $oracle_home" : "not set!";
	    warn "$ORACLE_ENV $msg\n";
	}

	# create a 'blank' dbh

	my $this = DBI::_new_dbh($drh, {
	    'Name' => $dbname,
	    'USER' => $user, 'CURRENT_USER' => $user,
	    });

	# Call Oracle OCI orlon func in Oracle.xs file
	# and populate internal handle data.
	DBD::Oracle::db::_login($this, $dbname, $user, $auth)
	    or return undef;

	$this;
    }

}


{   package DBD::Oracle::db; # ====== DATABASE ======
    use strict;

    sub errstr {
	return $DBD::Oracle::errstr;
    }

    sub prepare {
	my($dbh, $statement, @attribs)= @_;

	# create a 'blank' dbh

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

    sub tables {
	my($dbh) = @_;		# XXX add qualification
	my $sth = $dbh->prepare("select
		NULL		TABLE_CAT,
		at.OWNER	TABLE_SCHEM,
		at.TABLE_NAME,
		tc.TABLE_TYPE,
		tc.COMMENTS	TABLE_REMARKS
	    from ALL_TABLES at, ALL_TAB_COMMENTS tc
	    where at.OWNER = tc.OWNER
	    and at.TABLE_NAME = tc.TABLE_NAME
	");
	$sth->execute or return undef;
	$sth;
    }

    sub plsql_errstr {
	my ($dbh) = @_;
	# with thanks to Bob Menteer
	my (@msg, $line,$pos,$text);
	my $sth = $dbh->prepare(q{
	    select line,position,text from user_errors order by sequence
	});
	return undef unless $sth;
	$sth->execute or return undef;
	while(($line,$pos,$text) = $sth->fetchrow){
	    push @msg, "Error in PL/SQL block" unless @msg;
	    push @msg, "$line.$pos: $text";
	}
	join("\n", @msg);
    }
}


{   package DBD::Oracle::st; # ====== STATEMENT ======
    use strict;

    sub errstr {
	return $DBD::Oracle::errstr;
    }
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


=head1 SEE ALSO

L<DBI>

=head1 AUTHOR

DBD::Oracle by Tim Bunce.

=head1 COPYRIGHT

The DBD::Oracle module is Copyright (c) 1995,1996,1997 Tim Bunce. England.
The DBD::Oracle module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself with the exception that it
cannot be placed on a CD-ROM or similar media for commercial distribution
without the prior approval of the author.

=head1 ACKNOWLEDGEMENTS

See also L<DBI/ACKNOWLEDGEMENTS>.

=cut
