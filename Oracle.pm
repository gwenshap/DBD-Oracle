#   $Id: Oracle.pm,v 1.28 1996/05/20 21:53:26 timbo Exp $
#
#   Copyright (c) 1994,1995 Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

my $oracle_home;

{
    package DBD::Oracle;

    use DBI ();
    use DynaLoader ();
    @ISA = qw(DynaLoader);

    $VERSION = '0.31';
    my $Revision = substr(q$Revision: 1.28 $, 10);

    require_version DBI 0.69;

    bootstrap DBD::Oracle $VERSION;

    $err = 0;		# holds error code   for DBI::err
    $errstr = "";	# holds error string for DBI::errstr
    $drh = undef;	# holds driver handle once initialised
    %oratab = ();	# holds list of oratab databases (e.g., local)

    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;

	unless ($ENV{'ORACLE_HOME'}){
	    foreach(qw(/usr/oracle /opt/oracle /home/oracle /usr/soft/oracle)){
		$oracle_home = $_,last if -d "$_/rdbms/lib";
	    }
	}

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

    1;
}


{   package DBD::Oracle::dr; # ====== DRIVER ======
    use strict;

    sub errstr {
	DBD::Oracle::errstr(@_);
    }

    sub load_oratab {		# get list of 'local' databases
	my($drh) = @_;
	my $debug = $drh->debug;
	foreach(qw(/etc /var/opt/oracle), $ENV{TNS_ADMIN}) {
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

		$user .= $dbname;
	    }
	    elsif ($dbname =~ /:/){	# Implies an Sql*NET connection

		$user .= '@'.$dbname;
	    }
	    else {

		# Is this a NON-Sql*NET connection (ORACLE_SID)?
		# Or is it an alias for an Sql*NET connection (TWO_TASK)?
		# Sadly the 'user/passwd@machine' form only works
		# for Sql*NET connections.

		load_oratab($drh) unless %DBD::Oracle::oratab;

		my $orahome = $DBD::Oracle::oratab{$dbname};
		if ($orahome) { # is in oratab == is local
		    warn "Changing ORACLE_HOME for $dbname"
			if ($ENV{ORACLE_HOME} and $orahome ne $ENV{ORACLE_HOME});
		    $ENV{ORACLE_HOME} = $orahome;
		    $ENV{ORACLE_SID}  = $dbname;
		    delete $ENV{TWO_TASK};
		}
		else {
		    $user .= '@'.$dbname;	# assume it's an alias
		}
	    }
	}

	unless($ENV{ORACLE_HOME}) {	# last chance...
	    $ENV{ORACLE_HOME} = $oracle_home if $oracle_home;
	    my $msg = ($oracle_home) ? "set to $oracle_home" : "not set!";
	    warn "ORACLE_HOME $msg\n";
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
	DBD::Oracle::errstr(@_);
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

}


{   package DBD::Oracle::st; # ====== STATEMENT ======
    use strict;

    sub errstr {
	DBD::Oracle::errstr(@_);
    }
}

1;
