#!perl -w
#written by Lincoln A Baxter (lab@lincolnbaxter.com)

use strict;
#use warnings;
my $testcount = 12;
use Test::More;

BEGIN {
   use_ok( "DBI qw(:sql_types)" );
   use_ok( "DBD::Oracle qw(:ora_types ORA_OCI)" );
}

use DBI qw(:sql_types);
use DBD::Oracle qw(:ora_types ORA_OCI);

use File::Basename;

my $dirname = dirname( $0 );
#print "dirname=$dirname\n";

use Encode;


#binmode(STDOUT,":utf8");
#binmode(STDERR,":utf8");

my @widechars = ();  
push @widechars ,"\x{A1}" ;    #up side down bang (  )
push @widechars ,"\x{A2}" ;    #cent char (  )
push @widechars ,"\x{A3}" ;    #Brittish Pound char (  )
push @widechars ,"\x{263A}" if $ENV{DBD_NCHAR_SMILEY}; #smiley face from perl unicode man page
my $charcnt = @widechars;
plan tests => $testcount + $charcnt * 7;

print "testing utf8 chars:\n" ;
my $cnt = 1;
foreach my $c ( @widechars ) { 
   print "\trow $cnt nch_col will be nice_string=" . nice_string( $c ) ." bytes=".byte_string($c) ."\n" ;
   $cnt++;
}

my $table = "dbd_ora_nchar__drop_me";
my $dbh;
$| = 1;
SKIP: {
    skip "Unable to run unicode test, perl version is less than 5.6" ,$testcount unless ( $] >= 5.006 );

    eval {
       require utf8;
       import utf8;
    };
    skip "could not require or import utf8" ,$testcount if $@ ;
    skip "ORC_OCI < 8" ,$testcount, if (! ORA_OCI >= 8);

    warn show_nls_info();
    my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
    $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
        AutoCommit => 1,
        PrintError => 1,
    });
    #ok( $dbh ,"connect to oracle" ); $testcount--;
    skip "not connected to oracle" ,$testcount if not $dbh;
    skip "database NCHAR character set is not UTF8" ,$testcount if not check_ncharset() ;

    #TODO need a oracle 9i version test.... I guess I could clone one from Makefile.PL...


    #$dbh->{ora_ph_csform} = 2;
    # silently drop $table if it exists... 
    {
        local $dbh->{PrintError} = 0;
        $dbh->do(qq{ drop table $table });
    }

    ok( create_table( "ch_col VARCHAR2(20), nch_col NVARCHAR2(20)" ), "create table $table..." );
    my $cols = 'idx,ch_col,nch_col,dt' ;
    my $sstmt = "SELECT $cols FROM $table ORDER BY idx" ;

    my $sel_sth = $dbh->prepare($sstmt ); 
    ok( $sel_sth ,"prepare $sstmt" );

    ok( $sel_sth->execute, 'execute select ... empty table' );
    ok( (not $sel_sth->fetch() ), 'fetch ... empty table' );
    my $ustmt = "INSERT into $table( $cols ) values( ?,?,?,sysdate )" ;
    ok( $ustmt ,"insert statement handle prepared" );
    $dbh->do( "delete from $table" );

    my ($idx, $ch_col, $nch_col, $dt );
    $idx = 0;
    my $csform = $ENV{DBD_CSFORM} ? $ENV{DBD_CSFORM} : 2;
    my $upd_sth = $dbh->prepare( $ustmt );
    ok($upd_sth, "prepare $ustmt" );
    foreach my $widechar ( @widechars ) 
    {
        my $ord = ord( $widechar );
        #diag( "\ninserting wide char = '" .nice_string($widechar)."' ".sprintf("hex=%x dec=%d",$ord,$ord)."\n\n"  );
        my $colnum = 1;
        $idx++; 
        $ch_col = _achar($idx);
        $nch_col = $widechar ;
        ok($upd_sth->bind_param( $colnum++ ,$idx ), 'bind_param idx' );
        ok($upd_sth->bind_param( $colnum++ ,$ch_col ), "bind_param ch_col" );
        #ok($upd_sth->bind_param( $colnum++ ,$nch_col ), "bind_param nch_col IMPLICIT" );
        ok($upd_sth->bind_param( $colnum++ ,$nch_col ,{ ora_csform => $csform } ), "bind_param nch_col { ora_csform => $csform }" );
        ok($upd_sth->execute,"execute: $ustmt" );
    }

    #now we try to get the data out...
    ok($sel_sth->execute(),'select after inserting wide chars' );
    $idx = 0; $ch_col = ""; $nch_col = ""; $dt = "";
    {
       my $colnum = 1;
       ok($sel_sth->bind_col( $colnum++, \$idx  ), 'bind_col ch_col' ); 
       ok($sel_sth->bind_col( $colnum++, \$ch_col  ), 'bind_col ch_col' ); 
       ok($sel_sth->bind_col( $colnum++, 
                              \$nch_col ), 'bind_col nch_col (implicit)' ); 
                              #\$nch_col ,{ ora_csform => 2 } ), 'bind ncl_col ora_csform => (2) SQLCS_NCHAR' );
       ok($sel_sth->bind_col( $colnum++ ,\$dt ),   'bind_col dt' );
    }
    my $cnt = 0;
    while ( $sel_sth->fetch() )
    {
        $cnt++;
        #diag( "\nchecking nch_col for row #$cnt selected out\n\n" );
        cmp_ok( nice_string($ch_col) ,'eq',
                nice_string(_achar($cnt)),
                "test of ch_col for row $cnt (using nice_string -- utf8 expected)" 
              );
        cmp_ok( byte_string($nch_col) ,'eq',
                byte_string($widechars[$cnt-1]), 
                "test of nch_col for row $cnt (using byte_string -- byte comparison only)" 
              );
        cmp_ok( nice_string($nch_col) ,'eq',
                nice_string($widechars[$cnt-1]), 
                "test of nch_col for row $cnt (using nice_string -- utf8 expected)" 
              );
    }
    cmp_ok($cnt, '==', $charcnt, "number of rows fetched" );
    view_with_sqlplus(1) if $ENV{DBD_NCHAR_SQLPLUS_VIEW};
    view_with_sqlplus(0) if $ENV{DBD_NCHAR_SQLPLUS_VIEW};
    #pass( 'do not want test to fail yet' );
}

END {
    $dbh->do(qq{ drop table $table }) if $dbh and not $ENV{'DBD_SKIP_TABLE_DROP'};
}

sub _achar { chr(ord("@")+$_[0]); }
sub view_with_sqlplus
{
    my ( $use_nls_lang ) = @_ ;
    my $sqlfile = "sql.txt" ;
    my $cols = 'idx,nch_col' ;
    open F , ">$sqlfile" or die "could open $sqlfile";
    print F $ENV{ORACLE_USERID} ."\n";
    my $str = qq(
col idx form 99
col ch_col form a8
col nch_col form a16
select $cols from $table;
) ;
    print F $str;
    print F "exit;\n" ;
    close F;
    
    my $nls='unset';
    $nls = $ENV{NLS_LANG} if $ENV{NLS_LANG};
    $ENV{NLS_LANG} = '' if not $use_nls_lang;
    print "From sqlplus...$str\n  ...with NLS_LANG = $nls\n" ;
    system( "sqlplus -s \@$sqlfile" );
    $ENV{NLS_LANG} = $nls if $nls ne 'unset';
    unlink $sqlfile;
}

sub create_table {
    my ($fields, $drop) = @_;
    my $sql = "create table $table ( idx integer, $fields, dt date )";
    $dbh->do(qq{ drop table $table }) if $drop;
    $dbh->do($sql);
    if ($dbh->err && $dbh->err==955) {
        $dbh->do(qq{ drop table $table });
        warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
        $dbh->do($sql);
    }
    return 0 if $dbh->err;
    #print "$sql\n";
    return 1;
}

#from the perluniintro page:
#    $_[0] += 0;
#    print "nice_string: arg > 255\n" if $_[0] > 255;
#    print "nice_string: arg <= 255\n" if $_[0] <= 255;
#    return $_[0];
#    my $ret = chr($_[0]);
#    print "nice_string=$ret\n";
#    return $ret;
sub byte_string {
    my $ret = join( "+" ,unpack( "C*" ,$_[0] ) );
    #print "byte_string: $ret\n" ;
    return $ret;
}
sub nice_string {
    join("",
    map { $_ > 255 ?                  # if wide character...
          sprintf("\\x{%04X}", $_) :  # \x{...}
          chr($_) =~ /[[:cntrl:]]/ ?  # else if control character ...
          sprintf("\\x%02X", $_) :    # \x..
          chr($_)                     # else as themselves
    } unpack("U*", $_[0]));           # unpack Unicode characters
}

use Data::Dumper;
sub check_ncharset
{
    #verify the NLS NCHAR character set is 'UTF8'
    my $paramsH = $dbh->ora_nls_parameters();
    #warn Dumper( $paramsH );
    warn "Database character set is " .$paramsH->{NLS_CHARACTERSET} ."\n";
    warn "Database NCHAR character set is " .$paramsH->{NLS_NCHAR_CHARACTERSET} ."\n";
    if ( $paramsH->{NLS_NCHAR_CHARACTERSET} ne 'UTF8' ) {
        warn "Database NCHAR character set is not 'UTF8'\n" #  ."Some of these tests will likely fail\n"
        ;
        return 0;
    }
    return 1;
}

sub show_nls_info
{
   if ( not $ENV{NLS_LANG} ) { 
       $ENV{NLS_LANG} = 'AMERICAN_AMERICA.UTF8';
       return qq(
   NLS_LANG is not set. 
   Setting it to AMERICAN_AMERICA.UTF8
   consider setting NLS_LANG for your local
   other possible character sets that will work (for single byte chars) include:
       .WE8ISO8859P1
       .WE8MSWIN1252 ) ."\n\n";

   } else {
       return "\nNLS_LANG=" .$ENV{NLS_LANG}. "\n" ;
   }
}

__END__
