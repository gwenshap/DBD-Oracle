#!perl -w
#written by Lincoln A Baxter (lab@lincolnbaxter.com)

use strict;
#use warnings;
use Test::More;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

use DBI qw(:sql_types);
use DBD::Oracle qw(:ora_types ORA_OCI SQLCS_NCHAR );

my $dbh;
$| = 1;
SKIP: {
    plan skip_all => "Unable to run 8bit char test, perl version is less than 5.6" unless ( $] >= 5.006 );
    plan skip_all => "ORC_OCI < 8" if (! ORA_OCI >= 8);

    set_nls_nchar( 'WE8ISO8859P1' ,1 ); #   .WE8MSWIN1252 
    $dbh = db_handle();

    if ( 0 ) {
       $dbh->disconnect;
       undef $dbh;
       set_nls_charset( 'UTF8' ,1 );
       $dbh = db_handle();
       $dbh->disconnect;
       undef $dbh;
       exit(0);
    }
    plan skip_all => "Not connected to oracle" if not $dbh;
    plan skip_all => "Oracle version < 9" if not ( ORA_OCI >= 9 ); 

    print "testing control and 8 bit chars:\n" ;
    my $tdata = test_data( 'narrow_nchar' );
    my $testcount = 0 #create table
                  + insert_test_count( $tdata )
                  + select_test_count( $tdata ) * 1;
                  ;

    plan tests => $testcount ;
    #TODO need a oracle 9i version test.... I guess I could clone one from Makefile.PL...
    show_test_data( $tdata ,0 );

    drop_table($dbh);
    create_table( $dbh, $tdata );
    insert_rows( $dbh, $tdata ,SQLCS_NCHAR);
    dump_table( $dbh ,'nch' ,'descr' );
    select_rows( $dbh, $tdata );
    if ( 0 ) {
       $dbh->disconnect();
       set_nls_charset( 'UTF8' );
       $dbh = db_handle();
       select_rows( $dbh, $tdata );
    }
    if ( 0 ) {
       $dbh->disconnect();
       set_nls_charset( '' );
       $dbh = db_handle();
       select_rows( $dbh, $tdata );
    }
#    view_with_sqlplus(1,$tcols) if $ENV{DBD_NCHAR_SQLPLUS_VIEW};
#    view_with_sqlplus(0,$tcols) if $ENV{DBD_NCHAR_SQLPLUS_VIEW};
    #pass( 'do not want test to fail yet' );
}

END {
    eval {
        local $dbh->{PrintError} = 0;
	     drop_table( $dbh ) if $dbh and not $ENV{'DBD_SKIP_TABLE_DROP'};
    };
}

__END__

