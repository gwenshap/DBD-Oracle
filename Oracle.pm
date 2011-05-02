#   Oracle.pm
#
#   Copyright (c) 1994-2005 Tim Bunce, Ireland
#
#   See COPYRIGHT section in the documentation below

require 5.003;

$DBD::Oracle::VERSION = '1.19';

my $ORACLE_ENV  = ($^O eq 'VMS') ? 'ORA_ROOT' : 'ORACLE_HOME';

{
    package DBD::Oracle;

    use DBI ();
    use DynaLoader ();
    use Exporter ();
    @ISA = qw(DynaLoader Exporter);
    %EXPORT_TAGS = (
	ora_types => [ qw(
	    ORA_VARCHAR2 ORA_STRING ORA_NUMBER ORA_LONG ORA_ROWID ORA_DATE
	    ORA_RAW ORA_LONGRAW ORA_CHAR ORA_CHARZ ORA_MLSLABEL ORA_NTY
	    ORA_CLOB ORA_BLOB ORA_RSET
	) ],
        ora_session_modes => [ qw( ORA_SYSDBA ORA_SYSOPER ) ],
    );
    @EXPORT_OK = qw(ORA_OCI SQLCS_IMPLICIT SQLCS_NCHAR ora_env_var ora_cygwin_set_env);
    #unshift @EXPORT_OK, 'ora_cygwin_set_env' if $^O eq 'cygwin';
    Exporter::export_ok_tags(qw(ora_types ora_session_modes));

    my $Revision = substr(q$Revision: 1.103 $, 10);

    require_version DBI 1.28;

    bootstrap DBD::Oracle $VERSION;

    $drh = undef;	# holds driver handle once initialised

    sub CLONE {
        $drh = undef ;
    }
              
    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;
	my $oci = DBD::Oracle::ORA_OCI();

	$class .= "::dr";

	# not a 'my' since we use it above to prevent multiple drivers

	$drh = DBI::_new_drh($class, {
	    'Name' => 'Oracle',
	    'Version' => $VERSION,
	    'Err'    => \my $err,
	    'Errstr' => \my $errstr,
	    'Attribution' => "DBD::Oracle $VERSION using OCI$oci by Tim Bunce",
	    });
	DBD::Oracle::dr::init_oci($drh) ;
	$drh->STORE('ShowErrorStatement', 1);

	if ($DBI::VERSION >= 1.37) {
	    DBD::Oracle::db->install_method("ora_lob_read");
	    DBD::Oracle::db->install_method("ora_lob_write");
	    DBD::Oracle::db->install_method("ora_lob_append");
	    DBD::Oracle::db->install_method("ora_lob_trim");
	    DBD::Oracle::db->install_method("ora_lob_length");
	    DBD::Oracle::db->install_method("ora_nls_parameters");
	    DBD::Oracle::db->install_method("ora_can_unicode");
	}

	$drh;
    }


    END {
	# Used to silence 'Bad free() ...' warnings caused by bugs in Oracle's code
	# being detected by Perl's malloc.
	$ENV{PERL_BADFREE} = 0;
	#undef $Win32::TieRegistry::Registry if $Win32::TieRegistry::Registry;
    }

    sub AUTOLOAD {
    	(my $constname = $AUTOLOAD) =~ s/.*:://;
    	my $val = constant($constname);
    	*$AUTOLOAD = sub { $val };
    	goto &$AUTOLOAD;
    }

}


{   package DBD::Oracle::dr; # ====== DRIVER ======
    use strict;

    my %dbnames = ();	# holds list of known databases (oratab + tnsnames)

    sub load_dbnames {
	my ($drh) = @_;
	my $debug = $drh->debug;
	my $oracle_home = DBD::Oracle::ora_env_var($ORACLE_ENV);
	local *FH;
	my $d;

	if (($^O eq 'MSWin32') or ($^O =~ /cygwin/i)) {
	  # XXX experimental, will probably change
	  $drh->trace_msg("Trying to fetch ORACLE_HOME and ORACLE_SID from the registry.\n")
		if $debug;
	  my $sid = DBD::Oracle::ora_env_var("ORACLE_SID");
	  $dbnames{$sid} = $oracle_home if $sid and $oracle_home;
	  $drh->trace_msg("Found $sid \@ $oracle_home.\n") if $debug && $sid;
	}

	# get list of 'local' database SIDs from oratab
	foreach $d (qw(/etc /var/opt/oracle), DBD::Oracle::ora_env_var("TNS_ADMIN")) {
	    next unless defined $d;
	    next unless open(FH, "<$d/oratab");
	    $drh->trace_msg("Loading $d/oratab\n") if $debug;
	    my $ot;
	    while (defined($ot = <FH>)) {
		next unless $ot =~ m/^\s*(\w+)\s*:\s*(.*?)\s*:/;
		$dbnames{$1} = $2;	# store ORACLE_HOME value
		$drh->trace_msg("Found $1 \@ $2.\n") if $debug;
	    }
	    close FH;
	    last;
	}

	# get list of 'remote' database connection identifiers
	my @tns_admin;
	push @tns_admin, (
	  "$oracle_home/network/admin",	# OCI 7 and 8.1
	  "$oracle_home/net80/admin",	# OCI 8.0
	) if $oracle_home;
	push @tns_admin, "/var/opt/oracle";
	foreach $d ( DBD::Oracle::ora_env_var("TNS_ADMIN"), ".", @tns_admin  ) {
	    next unless $d && open(FH, "<$d/tnsnames.ora");
	    $drh->trace_msg("Loading $d/tnsnames.ora\n") if $debug;
	    local *_;
	    while (<FH>) {
		next unless m/^\s*([-\w\.]+)\s*=/;
		my $name = $1;
		$drh->trace_msg("Found $name. ".($dbnames{$name} ? "(oratab entry overridden)" : "")."\n")
		    if $debug;
		$dbnames{$name} = 0; # exists but false (to distinguish from oratab)
	    }
	    close FH;
	    last;
	}

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
	my ($drh, $dbname, $user, $auth, $attr)= @_;

	if ($dbname =~ /;/) {
	    my ($n,$v);
	    $dbname =~ s/^\s+//;
	    $dbname =~ s/\s+$//;
	    my @dbname = map {
		($n,$v) = split /\s*=\s*/, $_, -1;
		Carp::carp("DSN component '$_' is not in 'name=value' format")
		    unless defined $v && defined $n;
                (uc($n), $v)
	    } split /\s*;\s*/, $dbname;
	    my %dbname = ( PROTOCOL => 'tcp', @dbname );

	    # extract main attributes for connect_data portion
	    my @connect_data_attr = qw(SID INSTANCE_NAME SERVER SERVICE_NAME);
	    my %connect_data = map { ($_ => delete $dbname{$_}) }
		grep { exists $dbname{$_} } @connect_data_attr;
	    my $connect_data = join "", map { "($_=$connect_data{$_})" } keys %connect_data;

	    return $drh->DBI::set_err(-1,
		"Can't connect using this syntax without specifying a HOST and one of @connect_data_attr")
		unless $dbname{HOST} and %connect_data;

	    my @addrs = map { "($_=$dbname{$_})" } keys %dbname;
	    my $addrs = join "", @addrs;
	    if ($dbname{PORT}) {
		$addrs = "(ADDRESS=$addrs)";
	    }
	    else {
		$addrs = "(ADDRESS_LIST=(ADDRESS=$addrs(PORT=1526))"
				     . "(ADDRESS=$addrs(PORT=1521)))";
	    }
	    $dbname = "(DESCRIPTION=$addrs(CONNECT_DATA=$connect_data))";
	    $drh->trace_msg("connect using '$dbname'");
	}

	# If the application is asking for specific database
	# then we may have to mung the dbname

	$dbname = $1 if !$dbname && $user && $user =~ s/\@(.*)//s;

	$drh->trace_msg("$ORACLE_ENV environment variable not set\n")
		if !$ENV{$ORACLE_ENV} and $^O ne "MSWin32";

	# create a 'blank' dbh

	$user = '' if not defined $user;
        (my $user_only = $user) =~ s:/.*::;
	my ($dbh, $dbh_inner) = DBI::_new_dbh($drh, {
	    'Name' => $dbname,
	    # these two are just for backwards compatibility
	    'USER' => uc $user_only, 'CURRENT_USER' => uc $user_only,
	    });

	# Call Oracle OCI logon func in Oracle.xs file
	# and populate internal handle data.
	DBD::Oracle::db::_login($dbh, $dbname, $user, $auth, $attr)
	    or return undef;

	if ($attr && $attr->{ora_module_name}) {
	    eval {
		$dbh->do(q{BEGIN DBMS_APPLICATION_INFO.SET_MODULE(:1,NULL); END;},
		       undef, $attr->{ora_module_name});
	    };
	}
	unless (length $user_only) {
	    $user_only = $dbh->selectrow_array(q{
		SELECT SYS_CONTEXT('userenv','session_user') FROM DUAL
	    });
	    $dbh_inner->{Username} = $user_only;
	    # these two are just for backwards compatibility
	    $dbh_inner->{USER} = $dbh_inner->{CURRENT_USER} = uc $user_only;
	}

	$dbh;
    }

}


{   package DBD::Oracle::db; # ====== DATABASE ======
    use strict;
    use DBI qw(:sql_types);

    sub prepare {
	my($dbh, $statement, @attribs)= @_;

	# create a 'blank' sth

	my $sth = DBI::_new_sth($dbh, {
	    'Statement' => $statement,
	    });

	# Call Oracle OCI parse func in Oracle.xs file.
	# and populate internal handle data.

	DBD::Oracle::st::_prepare($sth, $statement, @attribs)
	    or return undef;

	$sth;
    }


    sub ping {
	my($dbh) = @_;
	my $ok = 0;
	eval {
	    local $SIG{__DIE__};
	    local $SIG{__WARN__};
	    # we know that Oracle 7 prepare does a describe so this will
	    # actually talk to the server and is this a valid and cheap test.
	    my $sth =  $dbh->prepare("select SYSDATE from DUAL /* ping */");
	    # But Oracle 8+ doesn't talk to server unless we describe the query
	    $ok = $sth && $sth->FETCH('NUM_OF_FIELDS');
	};
	return ($@) ? 0 : $ok;
    }


    sub get_info {
	my($dbh, $info_type) = @_;
	require DBD::Oracle::GetInfo;
	my $v = $DBD::Oracle::GetInfo::info{int($info_type)};
	$v = $v->($dbh) if ref $v eq 'CODE';
	return $v;
    }


    sub table_info {
	my($dbh, $CatVal, $SchVal, $TblVal, $TypVal) = @_;
	# XXX add knowledge of temp tables, etc
	# SQL/CLI (ISO/IEC JTC 1/SC 32 N 0595), 6.63 Tables
	if (ref $CatVal eq 'HASH') {
	    ($CatVal, $SchVal, $TblVal, $TypVal) =
		@$CatVal{'TABLE_CAT','TABLE_SCHEM','TABLE_NAME','TABLE_TYPE'};
	}
	my @Where = ();
	my $Sql;
	if ( defined $CatVal && $CatVal eq '%' && (!defined $SchVal || $SchVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19a
		$Sql = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , NULL TABLE_TYPE
     , NULL REMARKS
  FROM DUAL
SQL
	}
	elsif ( defined $SchVal && $SchVal eq '%' && (!defined $CatVal || $CatVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19b
		$Sql = <<'SQL';
SELECT NULL TABLE_CAT
     , s    TABLE_SCHEM
     , NULL TABLE_NAME
     , NULL TABLE_TYPE
     , NULL REMARKS
  FROM
(
  SELECT USERNAME s FROM ALL_USERS
  UNION
  SELECT 'PUBLIC' s FROM DUAL
)
 ORDER BY TABLE_SCHEM
SQL
	}
	elsif ( defined $TypVal && $TypVal eq '%' && (!defined $CatVal || $CatVal eq '') && (!defined $SchVal || $SchVal eq '') && (!defined $TblVal || $TblVal eq '')) { # Rule 19c
		$Sql = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , t.tt TABLE_TYPE
     , NULL REMARKS
  FROM
(
  SELECT 'TABLE'    tt FROM DUAL
    UNION
  SELECT 'VIEW'     tt FROM DUAL
    UNION
  SELECT 'SYNONYM'  tt FROM DUAL
    UNION
  SELECT 'SEQUENCE' tt FROM DUAL
) t
 ORDER BY TABLE_TYPE
SQL
	}
	else {
		$Sql = <<'SQL';
SELECT *
  FROM
(
  SELECT /*+ RULE*/
       NULL         TABLE_CAT
     , t.OWNER      TABLE_SCHEM
     , t.TABLE_NAME TABLE_NAME
     , decode(t.OWNER
	  , 'SYS'    , 'SYSTEM '
	  , 'SYSTEM' , 'SYSTEM '
          , '' ) || t.TABLE_TYPE TABLE_TYPE
     , c.COMMENTS   REMARKS
  FROM ALL_TAB_COMMENTS c
     , ALL_CATALOG      t
 WHERE c.OWNER      (+) = t.OWNER
   AND c.TABLE_NAME (+) = t.TABLE_NAME
   AND c.TABLE_TYPE (+) = t.TABLE_TYPE
)
SQL
		if ( defined $SchVal ) {
			push @Where, "TABLE_SCHEM LIKE '$SchVal' ESCAPE '\\'";
		}
		if ( defined $TblVal ) {
			push @Where, "TABLE_NAME  LIKE '$TblVal' ESCAPE '\\'";
		}
		if ( defined $TypVal ) {
			my $table_type_list;
			$TypVal =~ s/^\s+//;
			$TypVal =~ s/\s+$//;
			my @ttype_list = split (/\s*,\s*/, $TypVal);
			foreach my $table_type (@ttype_list) {
				if ($table_type !~ /^'.*'$/) {
					$table_type = "'" . $table_type . "'";
				}
				$table_type_list = join(", ", @ttype_list);
			}
			push @Where, "TABLE_TYPE IN ($table_type_list)";
		}
		$Sql .= ' WHERE ' . join("\n   AND ", @Where ) . "\n" if @Where;
		$Sql .= " ORDER BY TABLE_TYPE, TABLE_SCHEM, TABLE_NAME\n";
	}
	my $sth = $dbh->prepare($Sql) or return undef;
	$sth->execute or return undef;
	$sth;
}


    sub primary_key_info {
        my($dbh, $catalog, $schema, $table) = @_;
        if (ref $catalog eq 'HASH') {
            ($schema, $table) = @$catalog{'TABLE_SCHEM','TABLE_NAME'};
            $catalog = undef;
        }                  
	my $Sql = <<'SQL';
SELECT *
  FROM
(
  SELECT /*+ RULE*/
         NULL              TABLE_CAT
       , c.OWNER           TABLE_SCHEM
       , c.TABLE_NAME      TABLE_NAME
       , c.COLUMN_NAME     COLUMN_NAME
       , c.POSITION        KEY_SEQ
       , c.CONSTRAINT_NAME PK_NAME
    FROM ALL_CONSTRAINTS   p
       , ALL_CONS_COLUMNS  c
   WHERE p.OWNER           = c.OWNER
     AND p.TABLE_NAME      = c.TABLE_NAME
     AND p.CONSTRAINT_NAME = c.CONSTRAINT_NAME
     AND p.CONSTRAINT_TYPE = 'P'
)
 WHERE TABLE_SCHEM = ?
   AND TABLE_NAME  = ?
 ORDER BY TABLE_SCHEM, TABLE_NAME, KEY_SEQ
SQL
#warn "@_\n$Sql ($schema, $table)";
	my $sth = $dbh->prepare($Sql) or return undef;
	$sth->execute($schema, $table) or return undef;
	$sth;
}

    sub foreign_key_info {
	my $dbh  = shift;
	my $attr = ( ref $_[0] eq 'HASH') ? $_[0] : {
	    'UK_TABLE_SCHEM' => $_[1],'UK_TABLE_NAME ' => $_[2]
	   ,'FK_TABLE_SCHEM' => $_[4],'FK_TABLE_NAME ' => $_[5] };
	my $Sql = <<'SQL';  # XXX: DEFERABILITY
SELECT *
  FROM
(
  SELECT /*+ RULE*/
         to_char( NULL )    UK_TABLE_CAT
       , uk.OWNER           UK_TABLE_SCHEM
       , uk.TABLE_NAME      UK_TABLE_NAME
       , uc.COLUMN_NAME     UK_COLUMN_NAME
       , to_char( NULL )    FK_TABLE_CAT
       , fk.OWNER           FK_TABLE_SCHEM
       , fk.TABLE_NAME      FK_TABLE_NAME
       , fc.COLUMN_NAME     FK_COLUMN_NAME
       , uc.POSITION        ORDINAL_POSITION
       , 3                  UPDATE_RULE
       , decode( fk.DELETE_RULE, 'CASCADE', 0, 'RESTRICT', 1, 'SET NULL', 2, 'NO ACTION', 3, 'SET DEFAULT', 4 )
                            DELETE_RULE
       , fk.CONSTRAINT_NAME FK_NAME
       , uk.CONSTRAINT_NAME UK_NAME
       , to_char( NULL )    DEFERABILITY
       , decode( uk.CONSTRAINT_TYPE, 'P', 'PRIMARY', 'U', 'UNIQUE')
                            UNIQUE_OR_PRIMARY
    FROM ALL_CONSTRAINTS    uk
       , ALL_CONS_COLUMNS   uc
       , ALL_CONSTRAINTS    fk
       , ALL_CONS_COLUMNS   fc
   WHERE uk.OWNER            = uc.OWNER
     AND uk.CONSTRAINT_NAME  = uc.CONSTRAINT_NAME
     AND fk.OWNER            = fc.OWNER
     AND fk.CONSTRAINT_NAME  = fc.CONSTRAINT_NAME
     AND uk.CONSTRAINT_TYPE IN ('P','U')
     AND fk.CONSTRAINT_TYPE  = 'R'
     AND uk.CONSTRAINT_NAME  = fk.R_CONSTRAINT_NAME
     AND uk.OWNER            = fk.R_OWNER
     AND uc.POSITION         = fc.POSITION
)
 WHERE 1              = 1
SQL
	my @BindVals = ();
	while ( my ( $k, $v ) = each %$attr ) {
	    if ( $v ) {
		$Sql .= "   AND $k = ?\n";
		push @BindVals, $v;
	    }
	}
	$Sql .= " ORDER BY UK_TABLE_SCHEM, UK_TABLE_NAME, FK_TABLE_SCHEM, FK_TABLE_NAME, ORDINAL_POSITION\n";
	my $sth = $dbh->prepare( $Sql ) or return undef;
	$sth->execute( @BindVals ) or return undef;
	$sth;
    }


    sub column_info {
	my $dbh  = shift;
	my $attr = ( ref $_[0] eq 'HASH') ? $_[0] : {
	    'TABLE_SCHEM' => $_[1],'TABLE_NAME' => $_[2],'COLUMN_NAME' => $_[3] };
	my($typecase,$typecaseend) = ('','');
	if (ora_server_version($dbh)->[0] >= 8) {
	    $typecase = <<'SQL';
CASE WHEN tc.DATA_TYPE LIKE 'TIMESTAMP% WITH% TIME ZONE' THEN 95
     WHEN tc.DATA_TYPE LIKE 'TIMESTAMP%'                 THEN 93
     WHEN tc.DATA_TYPE LIKE 'INTERVAL DAY% TO SECOND%'   THEN 110
     WHEN tc.DATA_TYPE LIKE 'INTERVAL YEAR% TO MONTH'    THEN 107
ELSE
SQL
	    $typecaseend = 'END';
	}
	my $Sql = <<"SQL";
SELECT *
  FROM
(
  SELECT /*+ RULE*/
         to_char( NULL )     TABLE_CAT
       , tc.OWNER            TABLE_SCHEM
       , tc.TABLE_NAME       TABLE_NAME
       , tc.COLUMN_NAME      COLUMN_NAME
       , $typecase decode( tc.DATA_TYPE
         , 'MLSLABEL' , -9106
         , 'ROWID'    , -9104
         , 'UROWID'   , -9104
         , 'BFILE'    ,    -4 -- 31?
         , 'LONG RAW' ,    -4
         , 'RAW'      ,    -3
         , 'LONG'     ,    -1
         , 'UNDEFINED',     0
         , 'CHAR'     ,     1
         , 'NCHAR'    ,     1
         , 'NUMBER'   ,     decode( tc.DATA_SCALE, NULL, 8, 3 )
         , 'FLOAT'    ,     8
         , 'VARCHAR2' ,    12
         , 'NVARCHAR2',    12
         , 'BLOB'     ,    30
         , 'CLOB'     ,    40
         , 'NCLOB'    ,    40
         , 'DATE'     ,    93
         , NULL
         ) $typecaseend      DATA_TYPE          -- ...
       , tc.DATA_TYPE        TYPE_NAME          -- std.?
       , decode( tc.DATA_TYPE
         , 'LONG RAW' , 2147483647
         , 'LONG'     , 2147483647
         , 'CLOB'     , 2147483647
         , 'NCLOB'    , 2147483647
         , 'BLOB'     , 2147483647
         , 'BFILE'    , 2147483647
         , 'NUMBER'   , decode( tc.DATA_SCALE
                        , NULL, 126
                        , nvl( tc.DATA_PRECISION, 38 )
                        )
         , 'FLOAT'    , tc.DATA_PRECISION
         , 'DATE'     , 19
         , tc.DATA_LENGTH
         )                   COLUMN_SIZE
       , decode( tc.DATA_TYPE
         , 'LONG RAW' , 2147483647
         , 'LONG'     , 2147483647
         , 'CLOB'     , 2147483647
         , 'NCLOB'    , 2147483647
         , 'BLOB'     , 2147483647
         , 'BFILE'    , 2147483647
         , 'NUMBER'   , nvl( tc.DATA_PRECISION, 38 ) + 2
         , 'FLOAT'    ,  8 -- ?
         , 'DATE'     , 16
         , tc.DATA_LENGTH
         )                   BUFFER_LENGTH
       , decode( tc.DATA_TYPE
         , 'DATE'     ,  0
         , tc.DATA_SCALE
         )                   DECIMAL_DIGITS     -- ...
       , decode( tc.DATA_TYPE
         , 'FLOAT'    ,  2
         , 'NUMBER'   ,  decode( tc.DATA_SCALE, NULL, 2, 10 )
         , NULL
         )                   NUM_PREC_RADIX
       , decode( tc.NULLABLE
         , 'Y'        ,  1
         , 'N'        ,  0
         , NULL
         )                   NULLABLE
       , cc.COMMENTS         REMARKS
       , tc.DATA_DEFAULT     COLUMN_DEF         -- Column is LONG!
       , decode( tc.DATA_TYPE
         , 'MLSLABEL' , -9106
         , 'ROWID'    , -9104
         , 'UROWID'   , -9104
         , 'BFILE'    ,    -4 -- 31?
         , 'LONG RAW' ,    -4
         , 'RAW'      ,    -3
         , 'LONG'     ,    -1
         , 'UNDEFINED',     0
         , 'CHAR'     ,     1
         , 'NCHAR'    ,     1
         , 'NUMBER'   ,     decode( tc.DATA_SCALE, NULL, 8, 3 )
         , 'FLOAT'    ,     8
         , 'VARCHAR2' ,    12
         , 'NVARCHAR2',    12
         , 'BLOB'     ,    30
         , 'CLOB'     ,    40
         , 'NCLOB'    ,    40
         , 'DATE'     ,     9 -- not 93!
         , NULL
         )                   SQL_DATA_TYPE      -- ...
       , decode( tc.DATA_TYPE
         , 'DATE'     ,     3
         , NULL
         )                   SQL_DATETIME_SUB   -- ...
       , to_number( NULL )   CHAR_OCTET_LENGTH  -- TODO
       , tc.COLUMN_ID        ORDINAL_POSITION
       , decode( tc.NULLABLE
         , 'Y'        , 'YES'
         , 'N'        , 'NO'
         , NULL
         )                   IS_NULLABLE
    FROM ALL_TAB_COLUMNS  tc
       , ALL_COL_COMMENTS cc
   WHERE tc.OWNER         = cc.OWNER
     AND tc.TABLE_NAME    = cc.TABLE_NAME
     AND tc.COLUMN_NAME   = cc.COLUMN_NAME
)
 WHERE 1              = 1
SQL
	my @BindVals = ();
	while ( my ( $k, $v ) = each %$attr ) {
	    if ( $v ) {
		$Sql .= "   AND $k LIKE ? ESCAPE '\\'\n";
		push @BindVals, $v;
	    }
	}
	$Sql .= " ORDER BY TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION\n";
	my $sth = $dbh->prepare( $Sql ) or return undef;
	$sth->execute( @BindVals ) or return undef;
	$sth;
    }

    sub type_info_all {
	my ($dbh) = @_;
        my $version = ( ora_server_version($dbh)->[0] < DBD::Oracle::ORA_OCI() )
                    ?   ora_server_version($dbh)->[0] : DBD::Oracle::ORA_OCI();
        my $vc2len = ( $version < 8 ) ? "2000" : "4000";

	my $type_info_all = [
	    {
		TYPE_NAME          =>  0,
		DATA_TYPE          =>  1,
		COLUMN_SIZE        =>  2,
		LITERAL_PREFIX     =>  3,
		LITERAL_SUFFIX     =>  4,
		CREATE_PARAMS      =>  5,
		NULLABLE           =>  6,
		CASE_SENSITIVE     =>  7,
		SEARCHABLE         =>  8,
		UNSIGNED_ATTRIBUTE =>  9,
		FIXED_PREC_SCALE   => 10,
		AUTO_UNIQUE_VALUE  => 11,
		LOCAL_TYPE_NAME    => 12,
		MINIMUM_SCALE      => 13,
		MAXIMUM_SCALE      => 14,
		SQL_DATA_TYPE      => 15,
		SQL_DATETIME_SUB   => 16,
		NUM_PREC_RADIX     => 17,
		INTERVAL_PRECISION => 18,
	    },
	    [ "LONG RAW",        SQL_LONGVARBINARY, 2147483647,"'",  "'",
		undef,            1,0,0,undef,0,undef,
		"LONG RAW",        undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "RAW",             SQL_VARBINARY,     2000,      "'",  "'",
		"max length",     1,0,3,undef,0,undef,
		"RAW",             undef,undef,SQL_VARBINARY,    undef,undef,undef, ],
	    [ "LONG",            SQL_LONGVARCHAR,   2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"LONG",            undef,undef,SQL_LONGVARCHAR,  undef,undef,undef, ],
	    [ "CHAR",            SQL_CHAR,          2000,      "'",  "'",
		"max length",     1,1,3,undef,0,0,
		"CHAR",            undef,undef,SQL_CHAR,         undef,undef,undef, ],
	    [ "DECIMAL",         SQL_DECIMAL,       38,        undef,undef,
		"precision,scale",1,0,3,0,    0,0,
		"DECIMAL",         0,    38,   SQL_DECIMAL,      undef,10,   undef, ],
	    [ "DOUBLE PRECISION",SQL_DOUBLE,        15,        undef,undef,
		undef, 1,0,3,0,    0,0,
		"DOUBLE PRECISION",undef,undef,SQL_DOUBLE,       undef,10,   undef, ],
	    [ "DATE",            SQL_TYPE_TIMESTAMP,19,        "'",  "'",
		undef,            1,0,3,undef,0,0,
		"DATE",            0,    0,    SQL_DATE,         3,    undef,undef, ],
	    [ "VARCHAR2",        SQL_VARCHAR,       $vc2len,   "'",  "'",
		"max length",     1,1,3,undef,0,0,
		"VARCHAR2",        undef,undef,SQL_VARCHAR,      undef,undef,undef, ],
	];
	push @$type_info_all,
	    [ "BLOB",            SQL_LONGVARBINARY, 2147483647,"'",  "'",
		 undef,            1,1,0,undef,0,undef,
		"BLOB",            undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "BFILE",           SQL_LONGVARBINARY, 2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"BFILE",           undef,undef,SQL_LONGVARBINARY,undef,undef,undef, ],
	    [ "CLOB",            SQL_LONGVARCHAR,   2147483647,"'",  "'",
		undef,            1,1,0,undef,0,undef,
		"CLOB",            undef,undef,SQL_LONGVARCHAR,  undef,undef,undef, ],
	    if $version >= 8;
	return $type_info_all;
    }

    sub plsql_errstr {
	# original version thanks to Bob Menteer
	my $sth = shift->prepare_cached(q{
	    SELECT name, type, line, position, text
	    FROM user_errors ORDER BY name, type, sequence
	}) or return undef;
	$sth->execute or return undef;
	my ( @msg, $oname, $otype, $name, $type, $line, $pos, $text );
	$oname = $otype = 0;
	while ( ( $name, $type, $line, $pos, $text ) = $sth->fetchrow_array ) {
	    if ( $oname ne $name || $otype ne $type ) {
		push @msg, "Errors for $type $name:";
		$oname = $name;
		$otype = $type;
	    }
	    push @msg, "$line.$pos: $text";
	}
	return join( "\n", @msg );
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
	my $sth = $dbh->prepare_cached("begin dbms_output.get_line(:l, :s); end;")
		or return;
	my ($line, $status, @lines);
	# line can be greater that 255 (e.g. 7 byte date is expanded on output)
	$sth->bind_param_inout(':l', \$line,  400, { ora_type => 1 });
	$sth->bind_param_inout(':s', \$status, 20, { ora_type => 1 });
	if (!wantarray) {
	    $sth->execute or return undef;
	    return $line if $status eq '0';
	    return undef;
	}
	push @lines, $line while($sth->execute && $status eq '0');
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

 
    sub dbms_msgpipe_get {
	my $dbh = shift;
	my $sth = $dbh->prepare_cached(q{
	    begin dbms_msgpipe.get_request(:returnpipe, :proc, :param); end;
	}) or return;
	my $msg = ['','',''];
	$sth->bind_param_inout(":returnpipe", \$msg->[0],   30);
	$sth->bind_param_inout(":proc",       \$msg->[1],   30);
	$sth->bind_param_inout(":param",      \$msg->[2], 4000);
	$sth->execute or return undef;
	return $msg;
    }

    sub dbms_msgpipe_ack {
	my $dbh = shift;
	my $msg = shift;
	my $sth = $dbh->prepare_cached(q{
	    begin dbms_msgpipe.acknowledge(:returnpipe, :errormsg, :param); end;
	}) or return;
	$sth->bind_param_inout(":returnpipe", \$msg->[0],   30);
	$sth->bind_param_inout(":proc",       \$msg->[1],   30);
	$sth->bind_param_inout(":param",      \$msg->[2], 4000);
	$sth->execute or return undef;
	return 1;
    }

    sub ora_server_version {
	my $dbh = shift;
	return $dbh->{ora_server_version} if defined $dbh->{ora_server_version};
	$dbh->{ora_server_version} =
	   [ split /\./, $dbh->selectrow_array(<<'SQL', undef, 'Oracle%', 'Personal Oracle%') .''];
SELECT version
  FROM product_component_version
 WHERE product LIKE ? or product LIKE ?
SQL
    }

    sub ora_nls_parameters {
	my $dbh = shift;
	my $refresh = shift;

	if ($refresh || !$dbh->{ora_nls_parameters}) {
            my $nls_parameters = $dbh->selectall_arrayref(q{
		SELECT parameter, value FROM v$nls_parameters
	    }) or return;
	    $dbh->{ora_nls_parameters} = { map { $_->[0] => $_->[1] } @$nls_parameters };
	}

	# return copy of params to protect against accidental editing
	my %nls = %{$dbh->{ora_nls_parameters}};
	return \%nls;
    }

    sub ora_can_unicode {
	my $dbh = shift;
	my $refresh = shift;
	# 0 = No Unicode support.
	# 1 = National character set is Unicode-based.
	# 2 = Database character set is Unicode-based.
	# 3 = Both character sets are Unicode-based.

	return $dbh->{ora_can_unicode}
	    if defined $dbh->{ora_can_unicode} && !$refresh;

	my $nls = $dbh->ora_nls_parameters($refresh);

	$dbh->{ora_can_unicode}  = 0;
	$dbh->{ora_can_unicode} += 1 if $nls->{NLS_NCHAR_CHARACTERSET} =~ /UTF/;
	$dbh->{ora_can_unicode} += 2 if $nls->{NLS_CHARACTERSET}       =~ /UTF/;

	return $dbh->{ora_can_unicode};
    }

}   # end of package DBD::Oracle::db


{   package DBD::Oracle::st; # ====== STATEMENT ======

    sub execute_for_fetch {
       my ($sth, $fetch_tuple_sub, $tuple_status) = @_;
       my $row_count = 0;
       my $tuple_count=0;
       my $tuple_batch_status;
       my $dbh = $sth->{Database};
       my $batch_size =($dbh->{'ora_array_chunk_size'}||= 1000);
        
       if(defined($tuple_status)) {
           @$tuple_status = ();
           $tuple_batch_status = [ ];
       }
       
       while (1) {
           my @tuple_batch;
           for (my $i = 0; $i < $batch_size; $i++) {
                push @tuple_batch, [ @{$fetch_tuple_sub->() || last} ];
           }
           last unless @tuple_batch;
           my $res = ora_execute_array($sth,
                                           \@tuple_batch,
                                           scalar(@tuple_batch),
                                           $tuple_batch_status);
           if(defined($res) && defined($row_count)) {
                $row_count += $res;
           } else {
                $row_count = undef;
           }
           $tuple_count+=@$tuple_batch_status;
           push @$tuple_status, @$tuple_batch_status
           if defined($tuple_status);
       }
       if (!wantarray) {
	   return undef if !defined $row_count;
   	   return $tuple_count;
       }
       return (defined $row_count ? $tuple_count : undef, $row_count);
    }

}

1;

__END__

=head1 NAME

DBD::Oracle - Oracle database driver for the DBI module

=head1 SYNOPSIS

  use DBI;

  $dbh = DBI->connect("dbi:Oracle:$dbname", $user, $passwd);

  $dbh = DBI->connect("dbi:Oracle:host=$host;sid=$sid", $user, $passwd);

  # See the DBI module documentation for full details

  # for some advanced uses you may need Oracle type values:
  use DBD::Oracle qw(:ora_types);


=head1 DESCRIPTION

DBD::Oracle is a Perl module which works with the DBI module to provide
access to Oracle databases.

=head1 CONNECTING TO ORACLE

This is a topic which often causes problems. Mainly due to Oracle's many
and sometimes complex ways of specifying and connecting to databases.
(James Taylor and Lane Sharman have contributed much of the text in
this section.)

=head2 Connecting without environment variables or tnsname.ora file

If you use the C<host=$host;sid=$sid> style syntax, for example:

  $dbh = DBI->connect("dbi:Oracle:host=myhost.com;sid=ORCL", $user, $passwd);

then DBD::Oracle will construct a full connection descriptor string
for you and Oracle will not need to consult the tnsname.ora file.

If a C<port> number is not specified then the descriptor will try both
1526 and 1521 in that order (e.g., new then old).  You can check which
port(s) are in use by typing "$ORACLE_HOME/bin/lsnrctl stat" on the server.


=head2 Oracle Environment Variables

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

The ORACLE_HOME environment variable should be set correctly.
In general, the value used should match the version of Oracle that
was used to build DBD::Oracle.  If using dynamic linking then
ORACLE_HOME should match the version of Oracle that will be used
to load in the Oracle client libraries (via LD_LIBRARY_PATH, ldconfig,
or similar on Unix).

ORACLE_HOME can be left unset if you aren't using any of Oracle's
executables, but it is I<not> recommended and error messages may not display.
It should be set to the ORACLE_HOME directory of the version of Oracle
that DBD::Oracle was compiled with.

Discouraging the use of ORACLE_SID makes it easier on the users to see
what is going on. (It's unfortunate that TWO_TASK couldn't be renamed,
since it makes no sense to the end user, and doesn't have the ORACLE prefix).

=head2 Connection Examples Using DBD::Oracle

First, how to connect to a local database I<without> using a Listener:

  $dbh = DBI->connect('dbi:Oracle:SID','scott', 'tiger');

you can also leave the SID empty:

  $dbh = DBI->connect('dbi:Oracle:','scott', 'tiger');

in which case Oracle client code will use the ORACLE_SID environment
variable (if TWO_TASK env var isn't defined).

Below are various ways of connecting to an oracle database using
SQL*Net 1.x and SQL*Net 2.x.  "Machine" is the computer the database is
running on, "SID" is the SID of the database, "DB" is the SQL*Net 2.x
connection descriptor for the database.

B<Note:> Some of these formats may not work with Oracle 8+.

  BEGIN {
     $ENV{ORACLE_HOME} = '/home/oracle/product/7.x.x';
     $ENV{TWO_TASK}    = 'DB';
  }
  $dbh = DBI->connect('dbi:Oracle:','scott', 'tiger');
  #  - or -
  $dbh = DBI->connect('dbi:Oracle:','scott/tiger');

Refer to your Oracle documentation for valid values of TWO_TASK.

Here are some variations (not setting TWO_TASK) in order of preference:

  $dbh = DBI->connect('dbi:Oracle:DB','username','password')

  $dbh = DBI->connect('dbi:Oracle:DB','username/password','')

  $dbh = DBI->connect('dbi:Oracle:','username@DB','password')

  $dbh = DBI->connect('dbi:Oracle:host=foobar;sid=ORCL;port=1521', 'scott/tiger', '')

  $dbh = DBI->connect('dbi:Oracle:', q{scott/tiger@(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST= foobar)(PORT=1521))
  (CONNECT_DATA=(SID=ORCL)))}, "")

If you are having problems with login taking a long time (>10 secs say)
then you might have tripped up on an Oracle bug. You can try using one
of the ...@DB variants as a workaround. E.g.,

  $dbh = DBI->connect('','username/password@DB','');

On the other hand, that may cause you to trip up on another Oracle bug
that causes alternating connection attempts to fail! (In reality only
a small proportion of people experience these problems.)


To connect to a local database with a user which has been set-up to
authenticate via the OS ("ALTER USER username IDENTIFIED EXTERNALLY"):

  $dbh = DBI->connect('dbi:Oracle:','/','');

Note the lack of a connection name (use the ORACLE_SID environment
variable). If an explicit SID is used you'll probably get an ORA-01004 error.

That only works for local databases. (Authentication to remote Oracle
databases using your unix login name without a password and is possible
but it's not secure and not recommended so not documented here. If you
can't find the information elsewhere then you probably shouldn't be
trying to do it.)


=head2 Optimizing Oracle's listener

[By Lane Sharman <lane@bienlogic.com>] I spent a LOT of time optimizing
listener.ora and I am including it here for anyone to benefit from. My
connections over tnslistener on the same humble Netra 1 take an average
of 10-20 milli seconds according to tnsping. If anyone knows how to
make it better, please let me know!

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
             || die "Unable to connect to $dbname: $DBI::errstr\n";

=head2 Oracle utilities

If you are still having problems connecting then the Oracle adapters
utility may offer some help. Run these two commands:

  $ORACLE_HOME/bin/adapters
  $ORACLE_HOME/bin/adapters $ORACLE_HOME/bin/sqlplus

and check the output. The "Protocol Adapters" section should be the
same.  It should include at least "IPC Protocol Adapter" and "TCP/IP
Protocol Adapter".

If it generates any errors which look relevant then please talk to your
Oracle technical support (and not the dbi-users mailing list). Thanks.
Thanks to Mark Dedlow for this information.


=head2 Constants

=item :ora_session_modes

  ORA_SYSDBA ORA_SYSOPER

=item :ora_types

  ORA_VARCHAR2 ORA_STRING ORA_NUMBER ORA_LONG ORA_ROWID ORA_DATE
  ORA_RAW ORA_LONGRAW ORA_CHAR ORA_CHARZ ORA_MLSLABEL ORA_NTY
  ORA_CLOB ORA_BLOB ORA_RSET

=item SQLCS_IMPLICIT

=item SQLCS_NCHAR

SQLCS_IMPLICIT and SQLCS_NCHAR are I<character set form> values.
See notes about Unicode elsewhere in this document.

=item ORA_OCI

Oracle doesn't provide a formal API for determining the exact version
number of the OCI client library used, so DBD::Oracle has to go digging
(and sometimes has to more or less guess).  The ORA_OCI constant
holds the result of that process.

In string context ORA_OCI returns the full "A.B.C.D" version string.

In numeric context ORA_OCI returns the major.minor version number
(8.1, 9.2, 10.0 etc).  But note that version numbers are not actually
floating point and so if Oracle ever makes a release that has a two
digit minor version, such as C<9.10> it will have a lower numeric
value than the preceding C<9.9> release. So use with care.

The contents and format of ORA_OCI are subject to change (it may,
for example, become a I<version object> in later releases).
I recommend that you avoid checking for exact values.


=head2 Connect Attributes

=over 4

=item ora_session_mode

The ora_session_mode attribute can be used to connect with SYSDBA
authorization and SYSOPER authorization.
The ORA_SYSDBA and ORA_SYSOPER constants can be imported using

  use DBD::Oracle qw(:ora_session_modes);

This is one case where setting ORACLE_SID may be useful since
connecting as SYSDBA or SYSOPER via SQL*Net is frequently disabled
for security reasons.

Example:

  $dsn = "dbi:Oracle:";       # no dbname here
  $ENV{ORACLE_SID} = "orcl";  # set ORACLE_SID as needed
  delete $ENV{TWO_TASK};      # make sure TWO_TASK isn't set

  $dbh = DBI->connect($dsn, "", "", { ora_session_mode => ORA_SYSDBA });

It has been reported that this only works if $dsn does not contain a SID
so that Oracle then uses the value of the ORACLE_SID (not TWO_TASK)
environment variable to connect to a local instance. Also the username
and password should be empty, and the user executing the script needs
to be part of the dba group or osdba group.

=item ora_oratab_orahome

Passing a true value for the ora_oratab_orahome attribute will make
DBD::Oracle change $ENV{ORACLE_HOME} to make the Oracle home directory
specified in the C</etc/oratab> file I<if> the database to connect to
is specified as a SID that exists in the oratab file, and DBD::Oracle was
built to use the Oracle 7 OCI API (not Oracle 8+).

=item ora_module_name

After connecting to the database the value of this attribute is passed
to the SET_MODULE() function in the C<DBMS_APPLICATION_INFO> PL/SQL
package. This can be used to identify the application to the DBA for
monitoring and performance tuning purposes. For example:

  DBI->connect($dsn, $user, $passwd, { ora_module_name => $0 });

=item ora_dbh_share

Needs at least Perl 5.8.0 compiled with ithreads. Allows to share database
connections between threads. The first connect will make the connection, 
all following calls to connect with the same ora_dbh_share attribute
will use the same database connection. The value must be a reference
to a already shared scalar which is initialized to an empty string.

  our $orashr : shared = '' ;

  $dbh = DBI->connect ($dsn, $user, $passwd, {ora_dbh_share => \$orashr}) ;

=item ora_use_proc_connection

This attribute allows to create a DBI handle for an existing SQLLIB
database connection. This can be used to share database connections
between Oracle ProC code and DBI running in an embedded Perl interpreter.
The SQLLIB connection id is appended after the "dbi:Oracle:" initial
argument to DBI::connect.

For example, if in ProC a connection is made like

    EXEC SQL CONNECT 'user/pass@db' AT 'CONID';

the connection may be used from DBI after running something like

    my $dbh = DBI->connect("dbi:Oracle:CONID", "", "",
                           { ora_use_proc_connection => 1 });

To disconnect, first call $dbh->disconnect(), then disconnect in ProC.

This attribute requires DBD::Oracle to be built with the -ProC
option to Makefile.PL.  It is not available with OCI_V7. Not tested
with Perl ithreads or with the ora_dbh_share connect attribute.

=item ora_envhp

The first time a connection is made a new OCI 'environment' is
created by DBD::Oracle and stored in the driver handle.
Subsequent connects reuse (share) that same OCI environment
by default.

The ora_envhp attribute can be used to disable the reuse of the OCI
environment from a previous connect. If the value is C<0> then
a new OCI environment is allocated and used for this connection.

The OCI environment is what holds information about the client side
context, such as the local NLS environment. So by altering %ENV and
setting ora_envhp to 0 you can create connections with different
NLS settings. This is most useful for testing.

=back

=head2 Database Handle Attributes

=over 4

=item C<ora_ph_type>

The default placeholder data type for the database session.
The C<TYPE> or L</ora_type> attributes to L<DBI/bind_param> and
L<DBI/bind_param_inout> override the data type for individual placeholders.
The most frequent reason for using this attribute is to permit trailing spaces
in values passed by placeholders.

Constants for the values allowed for this attribute can be imported using

  use DBD::Oracle qw(:ora_types);

Only the following values are permitted for this attribute.

=over 4

=item ORA_VARCHAR2

Oracle clients using OCI 8 will strip trailing spaces and allow embedded \0 bytes.
Oracle clients using OCI 9.2 do not strip trailing spaces and allow embedded \0 bytes.
This is the normal default placeholder type.

=item ORA_STRING

Don't strip trailing spaces and end the string at the first \0.

=item ORA_CHAR

Don't strip trailing spaces and allow embedded \0.
Force 'blank-padded comparison semantics'.

For example:

  use DBD::Oracle qw(:ora_types);
  
  $sql="select username from all_users where username = ?";
  #username is a char(8)
   
  $sth=$dbh->prepare($sql)";
   
  $sth->bind_param(1,'bloggs',{ ora_type => ORA_CHAR});
   
Will pad bloggs out to 8 chracters and return the username.  

=back

=item ora_parse_error_offset

If the previous error was from a failed C<prepare> due to a syntax error,
this attribute gives the offset into the C<Statement> attribute where the
error was found.

=back

=over 4

=item ora_array_chunk_size

Because of OCI limitations, DBD::Oracle needs to buffer up rows of
bind values in its C<execute_for_fetch> implementation. This attribute
sets the number of rows to buffer at a time (default value is 1000).

The C<execute_for_fetch> function will collect (at most) this many
rows in an array, send them of to the DB for execution, then go back
to collect the next chunk of rows and so on. This attribute can be
used to limit or extend the number of rows processed at a time.

Note that this attribute also applies to C<execute_array>, since that
method is implemented using C<execute_for_fetch>.

=back

=head2 Prepare Attributes

These attributes may be used in the C<\%attr> parameter of the
L<DBI/prepare> database handle method.

=over 4

=item ora_placeholders

Set to false to disable processing of placeholders. Used mainly for loading a
PL/SQL package that has been I<wrapped> with Oracle's C<wrap> utility.

=item ora_parse_lang

Tells the connected database how to interpret the SQL statement.
If 1 (default), the native SQL version for the database is used.
Other recognized values are 0 (old V6, treated as V7 in OCI8),
2 (old V7), 7 (V7), and 8 (V8).
All other values have the same effect as 1.

=item ora_auto_lob

If true (the default), fetching retrieves the contents of the CLOB or
BLOB column in most circumstances.  If false, fetching retrieves the
Oracle "LOB Locator" of the CLOB or BLOB value.

See L</Handling LOBs> for more details.
See also the LOB tests in 05dbi.t of Oracle::OCI for examples
of how to use LOB Locators.

=item ora_check_sql

If 1 (default), force SELECT statements to be described in prepare().
If 0, allow SELECT statements to defer describe until execute().

See L</Prepare postponed till execute> for more information.

=back

=head2 Placeholder Binding Attributes

These attributes may be used in the C<\%attr> parameter of the
L<DBI/bind_param> or L<DBI/bind_param_inout> statement handle methods.

=over 4

=item ora_type

Specify the placeholder's data type using an Oracle data type.
A fatal error is raised if C<ora_type> and the DBI C<TYPE> attribute
are used for the same placeholder.
Some of these types are not supported by the current version of
DBD::Oracle and will cause a fatal error if used.
Constants for the Oracle datatypes may be imported using

  use DBD::Oracle qw(:ora_types);

Potentially useful values when DBD::Oracle was built using OCI 7 and later:

  ORA_VARCHAR2, ORA_STRING, ORA_LONG, ORA_RAW, ORA_LONGRAW,
  ORA_CHAR, ORA_MLSLABEL, ORA_RSET

Additional values when DBD::Oracle was built using OCI 8 and later:

  ORA_CLOB, ORA_BLOB, ORA_NTY

See L</Binding Cursors> for the correct way to use ORA_RSET.

See L</Handling LOBs> for how to use ORA_CLOB and ORA_BLOB.

See L</Other Data Types> for more information.

See also L<DBI/Placeholders and Bind Values>.

=item ora_csform

Specify the OCI_ATTR_CHARSET_FORM for the bind value. Valid values
are SQLCS_IMPLICIT (1) and SQLCS_NCHAR (2). Both those constants can
be imported from the DBD::Oracle module. Rarely needed.

=item ora_csid

Specify the I<integer> OCI_ATTR_CHARSET_ID for the bind value. 
Character set names can't be used currently.

=item ora_maxdata_size

Specify the integer OCI_ATTR_MAXDATA_SIZE for the bind value. 
May be needed if a character set conversion from client to server
causes the data to use more space and so fail with a truncation error.

=back

=head2 Trailing Spaces

Please note that only the Oracle OCI 8 strips trailing spaces from VARCHAR placeholder
values and uses Nonpadded Comparison Semantics with the result. 
This causes trouble if the spaces are needed for
comparison with a CHAR value or to prevent the value from
becoming '' which Oracle treats as NULL.
Look for Blank-padded Comparison Semantics and Nonpadded
Comparison Semantics in Oracle's SQL Reference or Server
SQL Reference for more details.

To preserve trailing spaces in placeholder values for Oracle clients that use OCI 8, 
either change the default placeholder type with L</ora_ph_type> or the placeholder
type for a particular call to L<DBI/bind> or L<DBI/bind_param_inout>
with L</ora_type> or C<TYPE>.
Using L<ORA_CHAR> with L<ora_type> or C<SQL_CHAR> with C<TYPE>
allows the placeholder to be used with Padded Comparison Semantics
if the value it is being compared to is a CHAR, NCHAR, or literal.

Please remember that using spaces as a value or at the end of
a value makes visually distinguishing values with different
numbers of spaces difficult and should be avoided.

Oracle Clients that use OCI 9.2 do not strip trailing spaces.

=head2 Padded Char Fields

Oracle Clients after OCI 9.2 will automatically pad CHAR placeholder values to the size of the CHAR.
As the default placeholder type value in DBD::Oracle is ORA_VARCHAR2 to access this behavior you will 
have to change the default placeholder type with L</ora_ph_type> or placeholder 
type for a particular call with L<DBI/bind> or L<DBI/bind_param_inout>
with L</ORA_CHAR> or C<ORA_CHARZ>.

=head1 Metadata

=head2 C<get_info()>

DBD::Oracle supports C<get_info()>, but (currently) only a few info types.

=head2 C<table_info()>

DBD::Oracle supports attributes for C<table_info()>.

In Oracle, the concept of I<user> and I<schema> is (currently) the
same. Because database objects are owned by an user, the owner names
in the data dictionary views correspond to schema names.
Oracle does not support catalogs so TABLE_CAT is ignored as
selection criterion.

Search patterns are supported for TABLE_SCHEM and TABLE_NAME.

TABLE_TYPE may contain a comma-separated list of table types.
The following table types are supported:

  TABLE
  VIEW
  SYNONYM
  SEQUENCE

The result set is ordered by TABLE_TYPE, TABLE_SCHEM, TABLE_NAME.

The special enumerations of catalogs, schemas and table types are
supported. However, TABLE_CAT is always NULL.

An identifier is passed I<as is>, i.e. as the user provides or
Oracle returns it.
C<table_info()> performs a case-sensitive search. So, a selection
criterion should respect upper and lower case.
Normally, an identifier is case-insensitive. Oracle stores and
returns it in upper case. Sometimes, database objects are created
with quoted identifiers (for reserved words, mixed case, special
characters, ...). Such an identifier is case-sensitive (if not all
upper case). Oracle stores and returns it as given.
C<table_info()> has no special quote handling, neither adds nor
removes quotes.

=head2 C<primary_key_info()>

Oracle does not support catalogs so TABLE_CAT is ignored as
selection criterion.
The TABLE_CAT field of a fetched row is always NULL (undef).
See L</table_info()> for more detailed information.

If the primary key constraint was created without an identifier,
PK_NAME contains a system generated name with the form SYS_Cn.

The result set is ordered by TABLE_SCHEM, TABLE_NAME, KEY_SEQ.

An identifier is passed I<as is>, i.e. as the user provides or
Oracle returns it.
See L</table_info()> for more detailed information.

=head2 C<foreign_key_info()>

This method (currently) supports the extended behavior of SQL/CLI, i.e. the
result set contains foreign keys that refer to primary B<and> alternate keys.
The field UNIQUE_OR_PRIMARY distinguishes these keys.

Oracle does not support catalogs, so C<$pk_catalog> and C<$fk_catalog> are
ignored as selection criteria (in the new style interface).
The UK_TABLE_CAT and FK_TABLE_CAT fields of a fetched row are always
NULL (undef).
See L</table_info()> for more detailed information.

If the primary or foreign key constraints were created without an identifier,
UK_NAME or FK_NAME contains a system generated name with the form SYS_Cn.

The UPDATE_RULE field is always 3 ('NO ACTION'), because Oracle (currently)
does not support other actions.

The DELETE_RULE field may contain wrong values. This is a known Bug (#1271663)
in Oracle's data dictionary views. Currently (as of 8.1.7), 'RESTRICT' and
'SET DEFAULT' are not supported, 'CASCADE' is mapped correctly and all other
actions (incl. 'SET NULL') appear as 'NO ACTION'.

The DEFERABILITY field is always NULL, because this columns is
not present in the ALL_CONSTRAINTS view of older Oracle releases.

The result set is ordered by UK_TABLE_SCHEM, UK_TABLE_NAME, FK_TABLE_SCHEM,
FK_TABLE_NAME, ORDINAL_POSITION.

An identifier is passed I<as is>, i.e. as the user provides or
Oracle returns it.
See L</table_info()> for more detailed information.

=head2 C<column_info()>

Oracle does not support catalogs so TABLE_CAT is ignored as
selection criterion.
The TABLE_CAT field of a fetched row is always NULL (undef).
See L</table_info()> for more detailed information.

The CHAR_OCTET_LENGTH field is (currently) always NULL (undef).

Don't rely on the values of the BUFFER_LENGTH field!
Especially the length of FLOATs may be wrong.

Datatype codes for non-standard types are subject to change.

Attention! The DATA_DEFAULT (COLUMN_DEF) column is of type LONG.

The result set is ordered by TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION.

An identifier is passed I<as is>, i.e. as the user provides or
Oracle returns it.
See L</table_info()> for more detailed information.


=head1 Unicode

DBD::Oracle now supports Unicode UTF-8. There are, however, a number
of issues you should be aware of, so please read all this section
carefully.

In this section we'll discuss "Perl and Unicode", then "Oracle and
Unicode", and finally "DBD::Oracle and Unicode".

Information about Unicode in general can be found at:
L<http://www.unicode.org/>. It is well worth reading because there are
many misconceptions about Unicode and you may be holding some of them.

=head2 Perl and Unicode

Perl began implementing Unicode with version 5.6, but the implementation
did not mature until version 5.8 and later. If you plan to use Unicode
you are I<strongly> urged to use perl 5.8.2 or later and to I<carefully> read
the perl documentaion on Unicode:

   perldoc perluniintro    # in perl 5.8 or later
   perldoc perlunicode

And then read it again.

Perl's internal unicode format is UTF-8
which corresponds to the Oracle character set called AL32UTF8.

=head2 Oracle and Unicode

Oracle supports many characters sets, including several different forms
of Unicode.  These include:

  AL16UTF16  =>  valid for NCHAR columns (CSID=2000)
  UTF8       =>  valid for NCHAR columns (CSID=871), deprecated
  AL32UTF8   =>  valid for NCHAR and CHAR columns (CSID=873)

When you create an Oracle database, you must specify the DATABASE 
character set (used for DDL, DML and CHAR datatypes) and the NATIONAL 
character set (used for NCHAR and NCLOB types).
The character sets used in your database can be found using:

  $hash_ref = $dbh->ora_nls_parameters()
  $database_charset = $hash_ref->{NLS_CHARACTERSET};
  $national_charset = $hash_ref->{NLS_NCHAR_CHARACTERSET};

The Oracle 9.2 and later default for the national character set is AL16UTF16.
The default for the database character set is often US7ASCII.
Although many experienced DBAs will consider an 8bit character set like
WE8ISO8859P1 or WE8MSWIN1252.  To use any character set with Oracle
other than US7ASCII, requires that the NLS_LANG environment variable be set.
See the L<"International NLS / 8-bit text issues"> section below.

You are strongly urged to read the Oracle Internationalization documentation
specifically with respect the choices and trade offs for creating
a databases for use with international character sets.

Oracle uses the NLS_LANG environment variable to indicate what
character set is being used on the client.  When fetching data Oracle
will convert from whatever the database character set is to the client
character set specified by NLS_LANG. Similarly, when sending data to
the database Oracle will convert from the character set specified by
NLS_LANG to the database character set.

The NLS_NCHAR environment variable can be used to define a different
character set for 'national' (NCHAR) character types.

Both UTF8 and AL32UTF32 can be used in NLS_LANG and NLS_NCHAR.
For example:

   NLS_LANG=AMERICAN_AMERICA.UTF8
   NLS_LANG=AMERICAN_AMERICA.AL32UTF8
   NLS_NCHAR=UTF8
   NLS_NCHAR=AL32UTF8

Oracle 8 client libraries have a number of bugs related to character
set handling, especially when connected to an Oracle 9+ server.
For this reason a number of DBD::Oracle tests are disabled when
using an Oracle 8 client. If you wish to use Unicode, I recommend
upgrading client and server to Oracle 9 or later.

=head2 Oracle UTF8 is not UTF-8

AL32UTF8 should be used in preference to UTF8 if it works for you,
which it should for Oracle 9.2 or later. If you're using an old
version of Oracle that doesn't support AL32UTF8 then you should
avoid using any Unicode characters that require surrogates, in other
words characters beyond the Unicode BMP (Basic Multilingual Plane).

That's because the character set that Oracle calls "UTF8" doesn't
conform to the UTF-8 standard in its handling of surrogate characters.
Technically the encoding that Oracle calls "UTF8" is known as "CESU-8".
Here are a couple of extracts from L<http://www.unicode.org/reports/tr26/>:

  CESU-8 is useful in 8-bit processing environments where binary
  collation with UTF-16 is required. It is designed and recommended
  for use only within products requiring this UTF-16 binary collation
  equivalence. It is not intended nor recommended for open interchange.

  As a very small percentage of characters in a typical data stream
  are expected to be supplementary characters, there is a strong
  possibility that CESU-8 data may be misinterpreted as UTF-8.
  Therefore, all use of CESU-8 outside closed implementations is
  strongly discouraged, such as the emittance of CESU-8 in output
  files, markup language or other open transmission forms.

Oracle uses this internally because it collates (sorts) in the same order
as UTF16, which is the basis of Oracle's internal collation definitions.

Rather than change UTF8 for clients Oracle chose to define a new character
set called "AL32UTF8" which does conform to the UTF-8 standard.
(The AL32UTF8 character set can't be used on the server because it
would break collation.)

Because of that, for the rest of this document we'll use "AL32UTF8".
If you're using an Oracle version below 9.2 you'll need to use "UTF8"
until you upgrade.

=head2 DBD::Oracle and Unicode

DBD::Oracle Unicode support has been implemented for Oracle versions 9
or greater, and perl version 5.6 or greater (though we I<strongly>
suggest that you use perl 5.8.2 or later).

You can check which Oracle version your DBD::Oracle was built with by
importing the C<ORA_OCI> constant from DBD::Oracle.

B<Fetching Data>

Any data returned from Oracle to DBD::Oracle in the AL32UTF8
character set will be marked as UTF-8 to ensure correct handling by perl.

For Oracle to return data in the AL32UTF8 character set the
NLS_LANG or NLS_NCHAR environment variable I<must> be set as described
in the previous section.

When fetching NCHAR, NVARCHAR, or NCLOB data from Oracle, DBD::Oracle
will set the perl UTF-8 flag on the returned data if either NLS_NCHAR
is AL32UTF8, or NLS_NCHAR is not set and NLS_LANG is AL32UTF8.

When fetching other character data from Oracle, DBD::Oracle
will set the perl UTF-8 flag on the returned data if NLS_LANG is AL32UTF8.

B<Sending Data using Placeholders>

Data bound to a placeholder is assumed to be in the default client
character set (specified by NLS_LANG) except for a few special
cases. These are listed here with the highest precedence first:

If the C<ora_csid> attribute is given to bind_param() then that
is passed to Oracle and takes precedence.

If the value is a Perl Unicode string (UTF-8) then DBD::Oracle
ensures that Oracle uses the Unicode character set, regardless of
the NLS_LANG and NLS_NCHAR settings.

If the placeholder is for inserting an NCLOB then the client NLS_NCHAR
character set is used. (That's useful but inconsistent with the other behaviour
so may change. Best to be explicit by using the C<ora_csform>
attribute.)

If the C<ora_csform> attribute is given to bind_param() then that
determines if the value should be assumed to be in the default
(NLS_LANG) or NCHAR (NLS_NCHAR) client character set. 


   use DBD::Oracle qw( SQLCS_IMPLICIT SQLCS_NCHAR );
   ...
   $sth->bind_param(1, $value, { ora_csform => SQLCS_NCHAR }); 

or

   $dbh->{ora_ph_csform} = SQLCS_NCHAR; # default for all future placeholders

B<Sending Data using SQL>

Oracle assumes the SQL statement is in the default client character
set (as specified by NLS_LANG). So Unicode strings containing
non-ASCII characters should not be used unless the default client
character set is AL32UTF8.

=head2 DBD::Oracle and Other Character Sets and Encodings

The only multi-byte Oracle character set supported by DBD::Oracle is
"AL32UTF8" (and "UTF8"). Single-byte character sets should work well.

=head1 Other Data Types

DBD::Oracle does not I<explicitly> support most Oracle data types.
It simply asks Oracle to return them as strings and Oracle does so.
Mostly.  Similarly when binding placeholder values DBD::Oracle binds
them as strings and Oracle converts them to the appropriate type,
such as DATE, when used.

Some of these automatic conversions to and from strings use NLS
settings to control the formating for output and the parsing for
input. The most common example is the DATE type. The default NLS
format for DATE might be DD-MON-YYYY and so when a DATE type is
fetched that's how Oracle will format the date. NLS settings also
control the default parsing of strings into DATE values. An error
will be generated if the contents of the string don't match the
NLS format. If you're dealing in dates which don't match the default
NLS format then you can either change the default NLS format or, more
commonly, use TO_CHAR(field, "format") and TO_DATE(?, "format")
to explicitly specify formats for converting to and from strings.

A slightly more subtle problem can occur with NUMBER types. The
default NLS settings might format numbers with a fullstop ("C<.>")
to separate thousands and a comma ("C<,>") as the decimal point.
Perl will generate warnings and use incorrect values when numbers,
returned and formatted as strings in this way by Oracle, are used
in a numeric context.  You could explicitly convert each numeric
value using the TO_CHAR(...) function but that gets tedious very
quickly. The best fix is to change the NLS settings. That can be
done for an individual connection by doing:

  $dbh->do("ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'");

There are some types, like BOOLEAN, that Oracle does not automatically
convert to or from strings (pity).  These need to be converted
explicitly using SQL or PL/SQL functions.

Examples:

   # DATE values
   my $sth0 = $dbh->prepare( <<SQL_END );
   SELECT username, TO_CHAR( created, ? )
      FROM all_users
      WHERE created >= TO_DATE( ?, ? )
   SQL_END
   $sth0->execute( 'YYYY-MM-DD HH24:MI:SS', "2003", 'YYYY' );

   # BOOLEAN values
   my $sth2 = $dbh->prepare( <<PLSQL_END );
   DECLARE
      b0 BOOLEAN;
      b1 BOOLEAN;
      o0 VARCHAR2(32);
      o1 VARCHAR2(32);

      FUNCTION to_bool( i VARCHAR2 ) RETURN BOOLEAN IS
      BEGIN
         IF    i IS NULL          THEN RETURN NULL;
         ELSIF i = 'F' OR i = '0' THEN RETURN FALSE;
         ELSE                          RETURN TRUE;
         END IF;
      END;
      FUNCTION from_bool( i BOOLEAN ) RETURN NUMBER IS
      BEGIN
         IF    i IS NULL THEN RETURN NULL;
         ELSIF i         THEN RETURN 1;
         ELSE                 RETURN 0;
         END IF;
      END;
   BEGIN
      -- Converting values to BOOLEAN
      b0 := to_bool( :i0 );
      b1 := to_bool( :i1 );

      -- Converting values from BOOLEAN
      :o0 := from_bool( b0 );
      :o1 := from_bool( b1 );
   END;
   PLSQL_END
   my ( $i0, $i1, $o0, $o1 ) = ( "", "Something else" );
   $sth2->bind_param( ":i0", $i0 );
   $sth2->bind_param( ":i1", $i1 );
   $sth2->bind_param_inout( ":o0", \$o0, 32 );
   $sth2->bind_param_inout( ":o1", \$o1, 32 );
   $sth2->execute();
   foreach ( $i0, $b0, $o0, $i1, $b1, $o1 ) {
      $_ = "(undef)" if ! defined $_;
   }
   print "$i0 to $o0, $i1 to $o1\n";
   # Result is : "'' to '(undef)', 'Something else' to '1'"


=head1 PL/SQL Examples

Most of these PL/SQL examples come from: Eric Bartley <bartley@cc.purdue.edu>.

   /*
    * PL/SQL to create package with stored procedures invoked by
    * Perl examples.  Execute using sqlplus.
    *
    * Use of "... OR REPLACE" prevents failure in the event that the
    * package already exists.
    */

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
  /

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
  /
  /* End PL/SQL for example package creation. */

  use DBI;

  my($db, $csr, $ret_val);

  $db = DBI->connect('dbi:Oracle:database','user','password')
        or die "Unable to connect: $DBI::errstr";

  # So we don't have to check every DBI call we set RaiseError.
  # See the DBI docs now if you're not familiar with RaiseError.
  $db->{RaiseError} = 1;

  # Example 1	Eric Bartley <bartley@cc.purdue.edu>
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


  # Example 2	Eric Bartley <bartley@cc.purdue.edu>
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


  # Example 3	Eric Bartley <bartley@cc.purdue.edu>
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


  # Example 4	Eric Bartley <bartley@cc.purdue.edu>
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

Oracle 9.2 appears to have a bug where a variable bound
with bind_param_inout() that isn't assigned to by the executed
PL/SQL block may contain garbage.
See L<http://www.mail-archive.com/dbi-users@perl.org/msg18835.html>

=head1 Private database handle functions

These functions are called through the method func()
which is described in the DBI documentation.

=head2 plsql_errstr

This function returns a string which describes the errors
from the most recent PL/SQL function, procedure, package,
or package body compile in a format similar to the output
of the SQL*Plus command 'show errors'.

The function returns undef if the error string could not
be retrieved due to a database error.
Look in $dbh->errstr for the cause of the failure.

If there are no compile errors, an empty string is returned.

Example:

    # Show the errors if CREATE PROCEDURE fails
    $dbh->{RaiseError} = 0;
    if ( $dbh->do( q{
        CREATE OR REPLACE PROCEDURE perl_dbd_oracle_test as
        BEGIN
            PROCEDURE filltab( stuff OUT TAB ); asdf
        END; } ) ) {} # Statement succeeded
    }
    elsif ( 6550 != $dbh->err ) { die $dbh->errstr; } # Utter failure
    else {
        my $msg = $dbh->func( 'plsql_errstr' );
        die $dbh->errstr if ! defined $msg;
        die $msg if $msg;
    }

=head2 dbms_output_enable / dbms_output_put / dbms_output_get

These functions use the PL/SQL DBMS_OUTPUT package to store and
retrieve text using the DBMS_OUTPUT buffer.  Text stored in this buffer
by dbms_output_put or any PL/SQL block can be retrieved by
dbms_output_get or any PL/SQL block connected to the same database
session.

Stored text is not available until after dbms_output_put or the PL/SQL
block that saved it completes its execution.  This means you B<CAN NOT>
use these functions to monitor long running PL/SQL procedures.

Example 1:

  # Enable DBMS_OUTPUT and set the buffer size
  $dbh->{RaiseError} = 1;
  $dbh->func( 1000000, 'dbms_output_enable' );

  # Put text in the buffer . . .
  $dbh->func( @text, 'dbms_output_put' );

  # . . . and retreive it later
  @text = $dbh->func( 'dbms_output_get' );

Example 2:

  $dbh->{RaiseError} = 1;
  $sth = $dbh->prepare(q{
    DECLARE tmp VARCHAR2(50);
    BEGIN
      SELECT SYSDATE INTO tmp FROM DUAL;
      dbms_output.put_line('The date is '||tmp);
    END;
  });
  $sth->execute;

  # retreive the string
  $date_string = $dbh->func( 'dbms_output_get' );


=over 4

=item dbms_output_enable ( [ buffer_size ] )

This function calls DBMS_OUTPUT.ENABLE to enable calls to package
DBMS_OUTPUT procedures GET, GET_LINE, PUT, and PUT_LINE.  Calls to
these procedures are ignored unless DBMS_OUTPUT.ENABLE is called
first.

The buffer_size is the maximum amount of text that can be saved in the
buffer and must be between 2000 and 1,000,000.  If buffer_size is not
given, the default is 20,000 bytes.

=item dbms_output_put ( [ @lines ] )

This function calls DBMS_OUTPUT.PUT_LINE to add lines to the buffer.

If all lines were saved successfully the function returns 1.  Depending
on the context, an empty list or undef is returned for failure.

If any line causes buffer_size to be exceeded, a buffer overflow error
is raised and the function call fails.  Some of the text might be in
the buffer.

=item dbms_output_get

This function calls DBMS_OUTPUT.GET_LINE to retrieve lines of text from
the buffer.

In an array context, all complete lines are removed from the buffer and
returned as a list.  If there are no complete lines, an empty list is
returned.

In a scalar context, the first complete line is removed from the buffer
and returned.  If there are no complete lines, undef is returned.

Any text in the buffer after a call to DBMS_OUTPUT.GET_LINE or
DBMS_OUTPUT.GET is discarded by the next call to DBMS_OUTPUT.PUT_LINE,
DBMS_OUTPUT.PUT, or DBMS_OUTPUT.NEW_LINE.

=item reauthenticate ( $username, $password )

Starts a new session against the current database using the credentials
supplied.

=item ora_nls_parameters ( [ $refresh ] )

Returns a hash reference containing the current NLS parameters, as given
by the v$nls_parameters view. The values fetched are cached between calls.
To cause the latest values to be fetched, pass a true value to the function.

=item ora_can_unicode ( [ $refresh ] )

Returns a number indicating whether either of the database character sets
is a Unicode encoding. Calls ora_nls_parameters() and passes the optional
$refresh parameter to it.

0 = Neither character set is a Unicode encoding.

1 = National character set is a Unicode encoding.

2 = Database character set is a Unicode encoding.

3 = Both character sets are Unicode encodings.

=back


=head1 Prepare postponed till execute

The DBD::Oracle module can avoid an explicit 'describe' operation
prior to the execution of the statement unless the application requests
information about the results (such as $sth->{NAME}). This reduces
communication with the server and increases performance (reducing the
number of PARSE_CALLS inside the server).

However, it also means that SQL errors are not detected until
C<execute()> (or $sth->{NAME} etc) is called instead of when
C<prepare()> is called. Note that if the describe is triggered by the
use of $sth->{NAME} or a similar attribute and the describe fails then
I<an exception is thrown> even if C<RaiseError> is false!

Set L</ora_check_sql> to 0 in prepare() to enable this behaviour.

=head1 Handling LOBs

=head2 Simple Usage

The value of an Oracle LOB column is not the content of the LOB. It's a
'LOB Locator' which, after being selected or inserted needs extra
processing to read or write the content of the LOB.

When fetching LOBs they are, by default, made to look just like LONGs and
are subject to the LongReadLen and LongTruncOk attributes. Note that
with OCI 7 DBD::Oracle pre-allocates the whole buffer (LongReadLen) at
the time the statement is prepared.  With OCI 8+ it grows the buffer to
the amount needed for the largest LOB to be fetched so far.

When inserting or updating LOBs some I<major> magic has to be performed
behind the scenes to make it transparent.  Basically the driver has to
insert a 'LOB Locator' and then refetch the newly inserted LOB
Locator before being able to write the data into it.  However, it works
well most of the time, and I've made it as fast as possible, just one
extra server-round-trip per insert or update after the first.  For the
time being, only single-row LOB updates are supported.

To insert or update a large LOB using a placeholder, DBD::Oracle has to
know in advance that it is a LOB type. So you need to say:

  $sth->bind_param($field_num, $lob_value, { ora_type => ORA_CLOB });

The ORA_CLOB and ORA_BLOB constants can be imported using

  use DBD::Oracle qw(:ora_types);

or use the corresponding integer values (112 and 113).

One further wrinkle: for inserts and updates of LOBs, DBD::Oracle has
to be able to tell which parameters relate to which table fields.
In all cases where it can possibly work it out for itself, it does,
however, if there are multiple LOB fields of the same type in the table
then you need to tell it which field each LOB param relates to:

  $sth->bind_param($idx, $value, { ora_type=>ORA_CLOB, ora_field=>'foo' });

There are some limitations inherent in the way DBD::Oracle makes typical
LOB operations simple by hiding the LOB Locator processing:

 - Can't read/write LOBs in chunks (except via DBMS_LOB.WRITEAPPEND in PL/SQL)
 - To INSERT a LOB, you need UPDATE privilege.

The alternative is to disable the automatic LOB Locator processing.
If L</ora_auto_lob> is 0 in prepare(), you can fetch the LOB Locators and
do all the work yourself using the ora_lob_*() methods and/or Oracle::OCI.
See the L</LOB Methods> section below.

=head2 LOB support in PL/SQL

LOB Locators can be passed to PL/SQL calls by binding them to placeholders
with the proper C<ora_type>.  If L</ora_auto_lob> is true, output LOB
parameters will be automatically returned as strings. 

If the Oracle driver has support for temporary LOBs (Oracle 9i and higher),
strings can be bound to input LOB placeholders and will be automatically 
converted to LOBs.

Example:
     # Build a large XML document, bind it as a CLOB,
     # extract elements through PL/SQL and return as a CLOB

     # $dbh is a connected database handle 
     # output will be large

     local $dbh->{LongReadLen} = 1_000_000;

     my $in_clob = "<document>\n";
     $in_clob .= "  <value>$_</value>\n" for 1 .. 10_000;
     $in_clob .= "</document>\n";

     my $out_clob;
     
     
     my $sth = $dbh->prepare(<<PLSQL_END);
     -- extract 'value' nodes
     DECLARE
       x XMLTYPE := XMLTYPE(:in);
     BEGIN
       :out := x.extract('/document/value').getClobVal();
     END;

     PLSQL_END
     
     # :in param will be converted to a temp lob
     # :out parameter will be returned as a string.

     $sth->bind_param( ':in', $in_clob, { ora_type => ORA_CLOB } );
     $sth->bind_param_inout( ':out', \$out_clob, 0, { ora_type => ORA_CLOB } );
     $sth->execute;


=head2 LOB Locator Methods

The following driver-specific methods let you manipulate "LOB Locators".
LOB locators can be selected from tables directly, if the C<ora_auto_lob>
attribute is false, or returned via PL/SQL procedure calls.

(If using a DBI version earlier than 1.36 they must be called via the
func() method. Note that methods called via func() don't honour
RaiseError etc, and so it's important to check $dbh->err after each call.
It's recommended that you upgrade to DBI 1.38 or later.)

Note that LOB locators are only valid while the statement handle that
created them is valid.  When all references to the original statement
handle are lost, the handle is destroyed and the locators are freed.

B<Warning:> Currently multi-byte character set issues have not been
fully worked out.  So these methods may not do what you expect if
either the perl data is utf8 or the CLOB is a multi-byte character set
(including uft8). The current behaviour in these situations may not be
correct and is B<subject to change>. I<Testing and patches are most welcome.>

=over 4

=item ora_lob_read

  $data = $dbh->ora_lob_read($lob_locator, $offset, $length);

Read a portion of the LOB. $offset starts at 1.
Uses the Oracle OCILobRead function.

=item ora_lob_write

  $rc = $dbh->ora_lob_write($lob_locator, $offset, $data);

Write/overwrite a portion of the LOB. $offset starts at 1.
Uses the Oracle OCILobWrite function.

=item ora_lob_append

  $rc = $dbh->ora_lob_append($lob_locator, $data);

Append $data to the LOB.  Uses the Oracle OCILobWriteAppend function.

NOTE: This method should I<not> be used if either the client or the
server are Oracle version 8 due to Oracle bug #886191.

=item ora_lob_trim

  $rc = $dbh->ora_lob_trim($lob_locator, $length);

Trims the length of the LOB to $length.
Uses the Oracle OCILobTrim function.

=item ora_lob_length

  $length = $dbh->ora_lob_length($lob_locator);

Returns the length of the LOB.
Uses the Oracle OCILobGetLength function.

=back

=head2 LOB Locator Method Examples

I<Note:> Make sure you first read the note in the section above about
multi-byte character set issues with these methods.

The following examples demonstrate the usage of LOB Locators
to read, write, and append data, and to query the size of
large data.

The following examples assume a table containing two large
object columns, one binary and one character, with a primary
key column, defined as follows:

   CREATE TABLE lob_example (
      lob_id      INTEGER PRIMARY KEY,
      bindata     BLOB,
      chardata    CLOB
   )

It also assumes a sequence for use in generating unique
lob_id field values, defined as follows:

   CREATE SEQUENCE lob_example_seq


=head2 Example: Inserting a new row with large data

Unless enough memory is available to store and bind the
entire lob data for insert all at once, the lob columns must
be written iteratively, piece by piece.  In the case of a new row,
this is performed by first inserting a row, with empty values in
the lob columns, then modifying the row by writing the large data
iteratively to the lob columns using their LOB locators as handles.

The insert statement must create token values in the lob
columns.  Here, we use the empty string for both the binary
and character large object columns 'bindata' and 'chardata'.

After the INSERT statement, a SELECT statement is used to
acquire lob locators to the 'bindata' and 'chardata' fields
of the newly inserted row.  Because these lob locators are
subsequently written, they must be acquired from a select
statement containing the clause 'FOR UPDATE' (lob locators
are only valid within the transaction that fetched them, so
can't be used effectively if AutoCommit is enabled).

   my $lob_id = $dbh->selectrow_array( <<"   SQL" );
      SELECT lob_example_seq.nextval FROM DUAL
   SQL

   my $sth = $dbh->prepare( <<"   SQL" );
      INSERT INTO lob_example
      ( lob_id, bindata, chardata )
      VALUES ( ?, EMPTY_BLOB(),EMPTY_CLOB() )
   SQL
   $sth->execute( $lob_id );

   $sth = $dbh->prepare( <<"   SQL", { ora_auto_lob => 0 } );
      SELECT bindata, chardata
      FROM lob_example
      WHERE lob_id = ?
      FOR UPDATE
   SQL
   $sth->execute( $lob_id );
   my ( $bin_locator, $char_locator ) = $sth->fetchrow_array();
   $sth->finish();

   open BIN_FH, "/binary/data/source" or die;
   open CHAR_FH, "/character/data/source" or die;
   my $chunk_size = 4096;   # Arbitrary chunk size

   # BEGIN WRITING BIN_DATA COLUMN
   my $offset = 1;   # Offsets start at 1, not 0
   my $length = 0;
   my $buffer = '';
   while( $length = read( BIN_FH, $buffer, $chunk_size ) ) {
      $dbh->ora_lob_write( $bin_locator, $offset, $buffer );
      $offset += $length;
   }

   # BEGIN WRITING CHAR_DATA COLUMN
   $offset = 1;   # Offsets start at 1, not 0
   $length = 0;
   $buffer = '';
   while( $length = read( CHAR_FH, $buffer, $chunk_size ) ) {
      $dbh->ora_lob_write( $char_locator, $offset, $buffer );
      $offset += $length;
   }


In this example we demonstrate the use of ora_lob_write()
iteratively to append data to the columns 'bin_data' and
'char_data'.  Had we used ora_lob_append(), we could have
saved ourselves the trouble of keeping track of the offset
into the lobs.  The snippet of code beneath the comment
'BEGIN WRITING BIN_DATA COLUMN' could look as follows:

   my $buffer = '';
   while ( read( BIN_FH, $buffer, $chunk_size ) ) {
      $dbh->ora_lob_append( $bin_locator, $buffer );
   }

The scalar variables $offset and $length are no longer
needed, because ora_lob_append() keeps track of the offset
for us.


=head2 Example: Updating an existing row with large data

In this example, we demonstrate a technique for overwriting
a portion of a blob field with new binary data.  The blob
data before and after the section overwritten remains
unchanged.  Hence, this technique could be used for updating
fixed length subfields embedded in a binary field.

   my $lob_id = 5;   # Arbitrary row identifier, for example

   $sth = $dbh->prepare( <<"   SQL", { ora_auto_lob => 0 } );
      SELECT bindata
      FROM lob_example
      WHERE lob_id = ?
      FOR UPDATE
   SQL
   $sth->execute( $lob_id );
   my ( $bin_locator ) = $sth->fetchrow_array();

   my $offset = 100234;
   my $data = "This string will overwrite a portion of the blob";
   $dbh->ora_lob_write( $bin_locator, $offset, $data );

After running this code, the row where lob_id = 5 will
contain, starting at position 100234 in the bin_data column,
the string "This string will overwrite a portion of the blob".

=head2 Example: Streaming character data from the database

In this example, we demonstrate a technique for streaming
data from the database to a file handle, in this case
STDOUT.  This allows more data to be read in and written out
than could be stored in memory at a given time.

   my $lob_id = 17;   # Arbitrary row identifier, for example

   $sth = $dbh->prepare( <<"   SQL", { ora_auto_lob => 0 } );
      SELECT chardata
      FROM lob_example
      WHERE lob_id = ?
   SQL
   $sth->execute( $lob_id );
   my ( $char_locator ) = $sth->fetchrow_array();

   my $chunk_size = 1034;   # Arbitrary chunk size, for example
   my $offset = 1;   # Offsets start at 1, not 0
   while( my $data = $dbh->ora_lob_read( $char_locator, $offset, $chunk_size ) ) {
      print STDOUT $data;
      $offset += $chunk_size;
   }

Notice that the select statement does not contain the phrase
"FOR UPDATE".  Because we are only reading from the lob
locator returned, and not modifying the lob it refers to,
the select statement does not require the "FOR UPDATE"
clause.

=head2 Example: Truncating existing large data

In this example, we truncate the data already present in a
large object column in the database.  Specifically, for each
row in the table, we truncate the 'bindata' value to half
its previous length.

After acquiring a lob locator for the column, we query its
length, then we trim the length by half.  Because we modify
the large objects with the call to ora_lob_trim(), we must
select the lob locators 'FOR UPDATE'.

   my $sth = $dbh->prepare( <<"   SQL", { ora_auto_lob => 0 } );
      SELECT bindata
      FROM lob_example
      FOR UPATE
   SQL
   $sth->execute();
   while( my ( $bin_locator ) = $sth->fetchrow_array() ) {
      my $binlength = $dbh->ora_lob_length( $bin_locator );
      if( $binlength > 0 ) {
         $dbh->ora_lob_trim( $bin_locator, $binlength/2 );
      }
   }

=head1 Binding Cursors

Cursors can be returned from PL/SQL blocks, either from stored
functions (or procedures with OUT parameters) or
from direct C<OPEN> statements, as shown below:

  use DBI;
  use DBD::Oracle qw(:ora_types);
  my $dbh = DBI->connect(...);
  my $sth1 = $dbh->prepare(q{
      BEGIN OPEN :cursor FOR
          SELECT table_name, tablespace_name
          FROM user_tables WHERE tablespace_name = :space;
      END;
  });
  $sth1->bind_param(":space", "USERS");
  my $sth2;
  $sth1->bind_param_inout(":cursor", \$sth2, 0, { ora_type => ORA_RSET } );
  $sth1->execute;
  # $sth2 is now a valid DBI statement handle for the cursor
  while ( my @row = $sth2->fetchrow_array ) { ... }

The only special requirement is the use of C<bind_param_inout()> with an
attribute hash parameter that specifies C<ora_type> as C<ORA_RSET>.
If you don't do that you'll get an error from the C<execute()> like:
"ORA-06550: line X, column Y: PLS-00306: wrong number or types of
arguments in call to ...".

Here's an alternative form using a function that returns a cursor.
This example uses the pre-defined weak (or generic) REF CURSOR type
SYS_REFCURSOR. This is an Oracle 9 feature. For Oracle 8, you must
create your own REF CURSOR type in a package (see the C<curref.pl>
script mentioned at the end of this section).

  # Create the function that returns a cursor
  $dbh->do(q{
      CREATE OR REPLACE FUNCTION sp_ListEmp RETURN SYS_REFCURSOR
      AS l_cursor SYS_REFCURSOR;
      BEGIN
          OPEN l_cursor FOR select ename, empno from emp
              ORDER BY ename;
          RETURN l_cursor;
      END;
  });

  # Use the function that returns a cursor
  my $sth1 = $dbh->prepare(q{BEGIN :cursor := sp_ListEmp; END;});
  my $sth2;
  $sth1->bind_param_inout(":cursor", \$sth2, 0, { ora_type => ORA_RSET } );
  $sth1->execute;
  # $sth2 is now a valid DBI statement handle for the cursor
  while ( my @row = $sth2->fetchrow_array ) { ... }

A cursor obtained from PL/SQL as above may be passed back to PL/SQL
by binding for input, as shown in this example, which explicitly
closes a cursor:

  my $sth3 = $dbh->prepare("BEGIN CLOSE :cursor; END;");
  $sth3->bind_param(":cursor", $sth2, { ora_type => ORA_RSET } );
  $sth3->execute;

It is not normally necessary to close a cursor
explicitly in this way. Oracle will close the cursor automatically
at the first client-server interaction after the cursor statement handle is
destroyed. An explicit close may be desirable if the reference to
the cursor handle from the PL/SQL statement handle delays the destruction
of the cursor handle for too long. This reference remains until the
PL/SQL handle is re-bound, re-executed or destroyed.

See the C<curref.pl> script in the Oracle.ex directory in the DBD::Oracle
source distribution for a complete working example.

=head1 Fetching Nested Cursors

Oracle supports the use of select list expressions of type REF CURSOR.
These may be explicit cursor expressions - C<CURSOR(SELECT ...)>, or
calls to PL/SQL functions which return REF CURSOR values. The values
of these expressions are known as nested cursors.

The value returned to a Perl program when a nested cursor is fetched
is a statement handle. This statement handle is ready to be fetched from.
It should not (indeed, must not) be executed.

Oracle imposes a restriction on the order of fetching when nested
cursors are used. Suppose C<$sth1> is a handle for a select statement
involving nested cursors, and C<$sth2> is a nested cursor handle fetched
from C<$sth1>. C<$sth2> can only be fetched from while C<$sth1> is
still active, and the row containing C<$sth2> is still current in C<$sth1>.
Any attempt to fetch another row from C<$sth1> renders all nested cursor
handles previously fetched from C<$sth1> defunct.

Fetching from such a defunct handle results in an error with the message
C<ERROR nested cursor is defunct (parent row is no longer current)>.

This means that the C<fetchall...> or C<selectall...> methods are not useful
for queries returning nested cursors. By the time such a method returns,
all the nested cursor handles it has fetched will be defunct.

It is necessary to use an explicit fetch loop, and to do all the
fetching of nested cursors within the loop, as the following example
shows:

    use DBI;
    my $dbh = DBI->connect(...);
    my $sth = $dbh->prepare(q{
        SELECT dname, CURSOR(
            SELECT ename FROM emp
                WHERE emp.deptno = dept.deptno
                ORDER BY ename
        ) FROM dept ORDER BY dname
    });
    $sth->execute;
    while ( my ($dname, $nested) = $sth->fetchrow_array ) {
        print "$dname\n";
        while ( my ($ename) = $nested->fetchrow_array ) {
            print "        $ename\n";
        }
    }


The cursor returned by the function C<sp_ListEmp> defined in the
previous section can be fetched as a nested cursor as follows:

    my $sth = $dbh->prepare(q{SELECT sp_ListEmp FROM dual});
    $sth->execute;
    my ($nested) = $sth->fetchrow_array;
    while ( my @row = $nested->fetchrow_array ) { ... }

=head2 Pre-fetching Nested Cursors

By default, DBD::Oracle pre-fetches rows in order to reduce the number of
round trips to the server. For queries which do not involve nested cursors,
the number of pre-fetched rows is controlled by the DBI database handle
attribute C<RowCacheSize> (q.v.).

In Oracle, server side open cursors are a controlled resource, limited in
number, on a per session basis, to the value of the initialization
parameter C<OPEN_CURSORS>. Nested cursors count towards this limit.
Each nested cursor in the current row counts 1, as does
each nested cursor in a pre-fetched row. Defunct nested cursors do not count.

An Oracle specific database handle attribute, C<ora_max_nested_cursors>,
further controls pre-fetching for queries involving nested cursors. For
each statement handle, the total number of nested cursors in pre-fetched
rows is limited to the value of this parameter. The default value
is 0, which disables pre-fetching for queries involving nested cursors.

=head1 Returning A Value from an INSERT

Oracle supports an extended SQL insert syntax which will return one
or more of the values inserted. This can be particularly useful for
single-pass insertion of values with re-used sequence values
(avoiding a separate "select seq.nextval from dual" step).

  $sth = $dbh->prepare(qq{
      INSERT INTO foo (id, bar)
      VALUES (foo_id_seq.nextval, :bar)
      RETURNING id INTO :id
  });
  $sth->bind_param(":bar", 42);
  $sth->bind_param_inout(":id", \my $new_id, 99);
  $sth->execute;
  print "The id of the new record is $new_id\n";

If you have many columns to bind you can use code like this:

  @params = (... column values for record to be inserted ...);
  $sth->bind_param($_, $params[$_-1]) for (1..@params);
  $sth->bind_param_inout(@params+1, \my $new_id, 99);
  $sth->execute;

=head1 Returning A Recordset

DBD::Oracle does not currently support binding a PL/SQL table (aka array)
as an IN OUT parameter to any Perl data structure.  You cannot therefore call
a PL/SQL function or procedure from DBI that uses a non-atomic data type as
either a parameter, or a return value.  However, if you are using Oracle 9.0.1
or later, you can make use of table (or pipelined) functions.

For example, assume you have the existing PL/SQL Package :

CREATE OR REPLACE PACKAGE Array_Example AS
    --
    TYPE tRec IS RECORD (
        Col1    NUMBER,
        Col2    VARCHAR2 (10),
        Col3    DATE) ;
    --
    TYPE taRec IS TABLE OF tRec INDEX BY BINARY_INTEGER ;
    --
    FUNCTION Array_Func RETURN taRec ;
    --
END Array_Example ;

CREATE OR REPLACE PACKAGE BODY Array_Example AS
--
FUNCTION Array_Func RETURN taRec AS
--
    l_Ret       taRec ;
--
BEGIN
    FOR i IN 1 .. 5 LOOP
        l_Ret (i).Col1 := i ;
        l_Ret (i).Col2 := 'Row : ' || i ;
        l_Ret (i).Col3 := TRUNC (SYSDATE) + i ;
    END LOOP ;
    RETURN l_Ret ;
END ;
--
END Array_Example ;
/

Currently, there is no way to directly call the function
Array_Example.Array_Func from DBI.  However, by making the following relatively
painless additions, its not only possible, but extremely efficient.

First, you need to create database object types that correspond to the record
and table types in the package.  From the above example, these would be :

  CREATE OR REPLACE TYPE tArray_Example__taRec
  AS OBJECT (
      Col1    NUMBER,
      Col2    VARCHAR2 (10),
      Col3    DATE
  ) ;

  CREATE OR REPLACE TYPE taArray_Example__taRec
  AS TABLE OF tArray_Example__taRec ;

Now, assuming the existing function needs to remain unchanged (it is probably
being called from other PL/SQL code), we need to add a new function to the
package.  Here's the new package specification and body :

  CREATE OR REPLACE PACKAGE Array_Example AS
      --
      TYPE tRec IS RECORD (
	  Col1    NUMBER,
	  Col2    VARCHAR2 (10),
	  Col3    DATE) ;
      --
      TYPE taRec IS TABLE OF tRec INDEX BY BINARY_INTEGER ;
      --
      FUNCTION Array_Func RETURN taRec ;
      FUNCTION Array_Func_DBI RETURN taArray_Example__taRec PIPELINED ;
      --
  END Array_Example ;

  CREATE OR REPLACE PACKAGE BODY Array_Example AS
  --
  FUNCTION Array_Func RETURN taRec AS
      l_Ret  taRec ;
  BEGIN
      FOR i IN 1 .. 5 LOOP
	  l_Ret (i).Col1 := i ;
	  l_Ret (i).Col2 := 'Row : ' || i ;
	  l_Ret (i).Col3 := TRUNC (SYSDATE) + i ;
      END LOOP ;
      RETURN l_Ret ;
  END ;

  FUNCTION Array_Func_DBI RETURN taArray_Example__taRec PIPELINED AS
      l_Set  taRec ;
  BEGIN
      l_Set := Array_Func ;
      FOR i IN l_Set.FIRST .. l_Set.LAST LOOP
	  PIPE ROW (
	      tArray_Example__taRec (
		  l_Set (i).Col1,
		  l_Set (i).Col2,
		  l_Set (i).Col3
	      )
	  ) ;
      END LOOP ;
      RETURN ;
  END ;
  --
  END Array_Example ;

As you can see, the new function is very simple.  Now, it is a simple matter
of calling the function as a straight-forward SELECT from your DBI code.  From
the above example, the code would look something like this :

  my $sth = $dbh->prepare('SELECT * FROM TABLE(Array_Example.Array_Func_DBI)');
  $sth->execute;
  while ( my ($col1, $col2, $col3) = $sth->fetchrow_array {
    ...
  }

=head1 Timezones

If TWO_TASK isn't set, Oracle uses the TZ variable from the local environment.
 
If TWO_TASK IS set, Oracle uses the TZ variable of the listener process
running on the server.

You could have multiple listeners, each with their own TZ, and assign
users to the appropriate listener by setting TNS_ADMIN to a directory
that contains a tnsnames.ora file that points to the port that their
listener is on.

[Brad Howerter, who supplied this info said: "I've done this to simulate
running a perl script at the end of the previous month even though it
was the 6th of the new month.  I had the dba start up a listener with
TZ=X+144.  (144 hours = 6 days)"]


=head1 Oracle Related Links

=head2 Oracle on Linux

  http://www.datamgmt.com/maillist.html
  http://www.eGroups.com/list/oracle-on-linux
  http://www.wmd.de/wmd/staff/pauck/misc/oracle_on_linux.html
  ftp://oracle-ftp.oracle.com/server/patch_sets/LINUX
  http://www.ixora.com.au/

=head2 Free Oracle Tools and Links

  ora_explain supplied and installed with DBD::Oracle.

  http://www.orafaq.com/

  http://vonnieda.org/oracletool/

=head2 Commercial Oracle Tools and Links

Assorted tools and references for general information.
No recommendation implied.

  http://www.platinum.com/products/oracle.htm
  http://www.SoftTreeTech.com
  http://www.databasegroup.com

Also PL/Vision from RevealNet and Steven Feuerstein, and
"Q" from Savant Corporation.


=head1 SEE ALSO

L<DBI>

http://search.cpan.org/~timb/DBD-Oracle/MANIFEST for all files in
the DBD::Oracle source distribution including the examples in the
Oracle.ex directory

  http://search.cpan.org/search?query=Oracle&mode=dist

=head1 AUTHOR

DBD::Oracle by Tim Bunce. DBI by Tim Bunce.

=head1 ACKNOWLEDGEMENTS

A great many people have helped me with DBD::Oracle over the 12 years
between 1994 and 2006.  Far too many to name, but I thank them all.
Many are named in the Changes file.

See also L<DBI/ACKNOWLEDGEMENTS>.

=head1 MAINTAINER

As of release 1.17 in February 2006 The Pythian Group, Inc. (L<http://www.pythian.com>)
are taking the lead in maintaining DBD::Oracle with my assistance and
gratitude. That frees more of my time to work on DBI for perl 5 and perl 6.

=head1 COPYRIGHT

The DBD::Oracle module is Copyright (c) 1994-2006 Tim Bunce. Ireland.

The DBD::Oracle module is free open source software; you can
redistribute it and/or modify it under the same terms as Perl 5.

=head1 CONTRIBUTING

If you'd like DBD::Oracle to do something new or different the best way
to make that happen is to do it yourself and email to dbi-dev@perl.org a
patch of the source code (using 'diff' - see below) that shows the changes.

=head2 How to create a patch using Subversion

The DBD::Oracle source code is maintained using Subversion (a replacement
for CVS, see L<http://subversion.tigris.org/>). To access the source
you'll need to install a Subversion client. Then, to get the source
code, do:

  svn checkout http://svn.perl.org/modules/dbd-oracle/trunk

If it prompts for a username and password use your perl.org account
if you have one, else just 'guest' and 'guest'. The source code will
be in a new subdirectory called C<trunk>.

To keep informed about changes to the source you can send an empty email
to dbd-oracle-changes-subscribe@perl.org after which you'll get an email with the
change log message and diff of each change checked-in to the source.

After making your changes you can generate a patch file, but before
you do, make sure your source is still upto date using:

  svn update 

If you get any conflicts reported you'll need to fix them first.
Then generate the patch file from within the C<trunk> directory using:

  svn diff > foo.patch

Read the patch file, as a sanity check, and then email it to dbi-dev@perl.org.

=head2 How to create a patch without Subversion

Unpack a fresh copy of the distribution:

  tar xfz DBD-Oracle-1.40.tar.gz

Rename the newly created top level directory:

  mv DBD-Oracle-1.40 DBD-Oracle-1.40.your_foo

Edit the contents of DBD-Oracle-1.40.your_foo/* till it does what you want.

Test your changes and then remove all temporary files:

  make test && make distclean

Go back to the directory you originally unpacked the distribution:

  cd ..

Unpack I<another> copy of the original distribution you started with:

  tar xfz DBD-Oracle-1.40.tar.gz

Then create a patch file by performing a recursive C<diff> on the two
top level directories:

  diff -r -u DBD-Oracle-1.40 DBD-Oracle-1.40.your_foo > DBD-Oracle-1.40.your_foo.patch

=head2 Speak before you patch

For anything non-trivial or possibly controversial it's a good idea
to discuss (on dbi-dev@perl.org) the changes you propose before
actually spending time working on them. Otherwise you run the risk
of them being rejected because they don't fit into some larger plans
you may not be aware of.

=cut
