#   $Id: Oracle.pm,v 1.23 1996/03/05 02:27:25 timbo Exp $
#
#   Copyright (c) 1994,1995 Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

{
    package DBD::Oracle;

    use DBI ();
    use DynaLoader ();
    @ISA = qw(DynaLoader);

    $VERSION = '0.29';
    my $Revision = substr(q$Revision: 1.23 $, 10);

	require_version DBI 0.68;

    bootstrap DBD::Oracle $VERSION;

    $err = 0;		# holds error code   for DBI::err
    $errstr = "";	# holds error string for DBI::errstr
    $drh = undef;	# holds driver handle once initialised

    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;

	unless ($ENV{'ORACLE_HOME'}){
	    foreach(qw(/usr/oracle /opt/oracle /home/oracle /usr/soft/oracle)){
		$ENV{'ORACLE_HOME'}=$_,last if -d "$_/rdbms/lib";
	    }
	    my $msg = ($ENV{ORACLE_HOME}) ? "set to $ENV{ORACLE_HOME}" : "not set!";
	    warn "ORACLE_HOME $msg\n";
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

    sub connect {
	my($drh, $dbname, $user, $auth)= @_;

	if ($dbname){	# application is asking for specific database

	    if ($dbname =~ /:/){	# Implies an Sql*NET connection

		# We can use the 'user/passwd@machine' form of user:
		$user .= '@'.$dbname;
		# $TWO_TASK and $ORACLE_SID will be ignored

	    } else {

		# Is this a NON-Sql*NET connection (ORACLE_SID)?
		# Or is it an alias for an Sql*NET connection (TWO_TASK)?
		# Sadly the 'user/passwd@machine' form only works
		# for Sql*NET connections.

		# We need a solution to this problem!
		# Perhaps we need to read and parse oracle
		# alias files like /etc/tnsnames.ora (/etc/sqlnet)

		$ENV{ORACLE_SID} = $dbname;
		delete $ENV{TWO_TASK};
	    }
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
