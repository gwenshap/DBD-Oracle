package DBD::Oracle::GetInfo;

use DBD::Oracle();

my $fmt = '%02d.%02d.%1d%1d%1d%1d';   # ODBC version string: ##.##.#####

my $sql_driver_ver = sprintf $fmt, split (/\./, "$DBD::Oracle::VERSION.0.0.0.0.0.0");

sub sql_dbms_version {
    my $dbh = shift;
    local $^W; # for ora_server_version having too few parts
    return sprintf $fmt, @{DBD::Oracle::db::ora_server_version($dbh)};
}
sub sql_data_source_name {
    my $dbh = shift;
    return 'dbi:Oracle:' . $dbh->{Name};
}
sub sql_user_name {
    my $dbh = shift;
    # XXX OPS$
    return $dbh->{CURRENT_USER};
}

%info = (
    117 =>  0                         # SQL_ALTER_DOMAIN
,   114 =>  2                         # SQL_CATALOG_LOCATION
, 10003 => 'N'                        # SQL_CATALOG_NAME
,    41 => '@'                        # SQL_CATALOG_NAME_SEPARATOR
,    42 => 'Database Link'            # SQL_CATALOG_TERM
,    87 => 'Y'                        # SQL_COLUMN_ALIAS
,    22 =>  1                         # SQL_CONCAT_NULL_BEHAVIOR
,   127 =>  0                         # SQL_CREATE_ASSERTION
,   130 =>  0                         # SQL_CREATE_DOMAIN
,     2 => \&sql_data_source_name     # SQL_DATA_SOURCE_NAME
,    17 => 'Oracle'                   # SQL_DBMS_NAME
,    18 => \&sql_dbms_version         # SQL_DBMS_VERSION
,     6 => 'DBD/Oracle.pm'            # SQL_DRIVER_NAME
,     7 =>  $sql_driver_ver           # SQL_DRIVER_VER
,   136 =>  0                         # SQL_DROP_ASSERTION
,   139 =>  0                         # SQL_DROP_DOMAIN
,    28 =>  1                         # SQL_IDENTIFIER_CASE
,    29 => '"'                        # SQL_IDENTIFIER_QUOTE_CHAR
,    34 =>  0                         # SQL_MAX_CATALOG_NAME_LEN
,    30 => 30                         # SQL_MAX_COLUMN_NAME_LEN
, 10005 => 30                         # SQL_MAX_IDENTIFIER_LEN
,    32 => 30                         # SQL_MAX_OWNER_NAME_LEN
,    34 =>  0                         # SQL_MAX_QUALIFIER_NAME_LEN
,    32 => 30                         # SQL_MAX_SCHEMA_NAME_LEN
,    35 => 30                         # SQL_MAX_TABLE_NAME_LEN
,   107 => 30                         # SQL_MAX_USER_NAME_LEN
,    90 => 'N'                        # SQL_ORDER_BY_COLUMNS_IN_SELECT
,    39 => 'Owner'                    # SQL_OWNER_TERM
,    40 => 'Procedure'                # SQL_PROCEDURE_TERM
,   114 =>  2                         # SQL_QUALIFIER_LOCATION
,    41 => '@'                        # SQL_QUALIFIER_NAME_SEPARATOR
,    42 => 'Database Link'            # SQL_QUALIFIER_TERM
,    93 =>  3                         # SQL_QUOTED_IDENTIFIER_CASE
,    39 => 'Owner'                    # SQL_SCHEMA_TERM
,    14 => '\\'                       # SQL_SEARCH_PATTERN_ESCAPE
,    13 =>  sub {"$_[0]->{Name}"}     # SQL_SERVER_NAME
,    94 => '$#'                       # SQL_SPECIAL_CHARACTERS
,    45 => 'Table'                    # SQL_TABLE_TERM
,    46 =>  3                         # SQL_TXN_CAPABLE
,    47 => \&sql_user_name            # SQL_USER_NAME
);

1;
