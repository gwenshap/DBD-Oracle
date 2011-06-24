#!perl -w
use strict;

use DBI;
use DBD::Oracle;

use Test::More;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

my $dbh = db_handle();

$dbh->do( 'DROP TABLE RT30133' );

$dbh->do( 'ALTER SYSTEM SET ENCRYPTION KEY IDENTIFIED BY shazam' )
    or die $dbh->errstr;

$dbh->do( <<'SQL' ) or die $dbh->errstr;
CREATE TABLE RT30133(
    COL_INTEGER NUMBER(38),
    COL_INTEGER_ENCRYPT NUMBER(38) ENCRYPT,
    COL_DECIMAL NUMBER(9,2),
    COL_DECIMAL_ENCRYPT NUMBER(9,2) ENCRYPT,
    COL_FLOAT FLOAT(126)
) 
SQL

my $sth = $dbh->prepare( 'select * from RT30133' );
my $columnCount = $sth->{NUM_OF_FIELDS};
my @columnNames;
for(my $i=0; $i < $columnCount; $i++)
{
my $colName = @{$sth->{NAME}}[$i];
my $typeNum = @{$sth->{TYPE}}[$i];
my $typeName = $dbh->type_info($typeNum)->{TYPE_NAME};
my $precision = @{$sth->{PRECISION}}[$i];
my $scale = @{$sth->{SCALE}}[$i];
my @attrs = ($colName,$typeNum,$typeName,$precision,$scale);
print join(",", @attrs), "\n";
}
