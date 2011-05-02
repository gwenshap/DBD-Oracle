#!perl -w

use Test::More;

use DBI;
use Oraperl;
use Config;
use DBD::Oracle qw(:ora_types);



## ----------------------------------------------------------------------------
## 33pres_lobs.t
## By John Scoles, The Pythian Group
## ----------------------------------------------------------------------------
##  Checks to see if the Interface for Persistent LOBs is working
##  Nothing fancy. Just an insert and a select if they fail this there is something up in OCI or the version 
##  of oci being used
## ----------------------------------------------------------------------------

unshift @INC ,'t';
require 'nchar_test_lib.pl';

$| = 1;

plan tests => 11;

# create a database handle
my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect($dsn, $dbuser, '', { RaiseError=>1, 
						AutoCommit=>1,
						PrintError => 0 });
# check that our db handle is good
my $ora_oci = DBD::Oracle::ORA_OCI(); # dualvar

SKIP: {
   	skip "OCI version less than 10.2\n Persistent LOBs Tests skiped.", 11 unless $ora_oci >= 10.2;
     

my $table = table();


ok($dbh->do(qq{
	CREATE TABLE $table (
	    id NUMBER,
	    clob1 CLOB, 
	    clob2 CLOB, 
	    blob1 BLOB, 
	    blob2 BLOB)
    }));


my $in_clob='ABCD' x 10_000;
my $in_blob=("0\177x\0X"x 2048) x (1);
my ($sql, $sth,$value);

$sql = "insert into ".$table."
	(id,clob1,clob2, blob1,blob2)
	values(?,?,?,?,?)";
ok($sth=$dbh->prepare($sql ));
$sth->bind_param(1,3);
ok($sth->bind_param(2,$in_clob,{ora_type=>SQLT_CHR}));
ok($sth->bind_param(3,$in_clob,{ora_type=>SQLT_CHR}));
ok($sth->bind_param(4,$in_blob,{ora_type=>SQLT_BIN}));
ok($sth->bind_param(5,$in_blob,{ora_type=>SQLT_BIN}));
ok($sth->execute());

ok($dbh->{LongReadLen} = 1000000); #twice as big as it should be

$sql='select * from '.$table;

ok($sth=$dbh->prepare($sql,{ora_pers_lob=>1}));

ok($sth->execute());

ok(my ( $p_id,$log,$log2,$log3,$log4 )=$sth->fetchrow());

#no neeed to look at the data is should be ok

$sth->finish();
drop_table($dbh);
}


$dbh->disconnect;

1;
