#!perl -w
#test of NCHAR NVARCHAR2 column types... (unicode support)...
#created by Lincoln A Baxter (lab@lincolnbaxter.com)

use DBI qw(:sql_types);
use DBD::Oracle qw(:ora_types ORA_OCI);
use strict;

#binmode(STDOUT,":utf8");
#binmode(STDERR,":utf8");

sub ok ($$;$);
my $tests;

$| = 1;
unless ( $] >= 5.006 ) {
    warn "Unable to run unicode test, perl version is less than 5.6\n"
        ."Tests skiped.\n" ;
    print "1..0\n";
    exit 0;
}

BEGIN { 
   #unless ( $ENV{NLS_LANG} && $ENV{NLS_LANG} =~ m/utf/i ) {
   if ( not $ENV{NLS_LANG} ) { 
       warn 
qq(NLS_LANG was not set.
To run unicode (nchar) tests consider:
   export NLS_LANG=AMERICAN_AMERICA.UTF8 && make test 
or
   NLS_LANG=AMERICAN_AMERICA.UTF8 perl -Mblib t/nchar.t
);
    } else {
       print "NLS_LANG=" .$ENV{NLS_LANG}. "\n" ;
    
    #print "1..0\n";
    #exit 0;
    #$ENV{NLS_LANG} = 'AMERICAN_AMERICA.UTF8';
   }
}

#eval {
#   require utf8;
#   import utf8;
#};
if ( $@ )
{
   warn "could not require utf8\n$@Test skipped\n";
   print "1..0\n";
   exit 0;
}

my $t = 0;
my $failed = 0;
my $table = "dbd_ora__drop_me";

my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
	AutoCommit => 1,
	PrintError => 1,
});

unless($dbh) {
    warn "Unable to connect to Oracle ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
}
$dbh->{ora_ph_csform} = 2;

unless (ORA_OCI >= 8) {
    warn "Unable to run unicode tests\nTests skiped.\n";
    print "1..0\n";
    exit 0;
}
#TODO need a oracle 9i version test.... I guess I could clone one
#from Makefile.PL...

{
    local $dbh->{PrintError} = 0;
    $dbh->do(qq{ drop table $table });
}

{
   my @warn;
   #verify the database character sets have 'UTF' in them
   my $sth = $dbh->prepare( "select PARAMETER,VALUE from NLS_DATABASE_PARAMETERS where PARAMETER like ?" );
   $sth->execute( '%CHARACTERSET' );
   my ( $value, $param );
   $sth->bind_col( 1 ,\$param );
   $sth->bind_col( 2 ,\$value );
   my $cnt = 0;
   while ( $sth->fetch() ) {
       $cnt++;
       print "$param=$value\n" ;
       unless ( $value =~ m/UTF/ ) {
          push @warn, "Database $param value does not contain string 'UTF'\n";
       }
   }
   push @warn, "did not fetch 2 rows from NLS_DATABASE_PARAMETERS where PARAMETER like \%CHARACTERSET\n"
	unless $cnt == 2;

    if (@warn) {
	warn @warn;
    # just skip for now
	print "1..0\n";
	exit 0;
    }
}

#unless(create_table("col1 VARCHAR2(20), col2 VARCHAR2(20)")) {
unless(create_table("col1 VARCHAR2(20), col2 NVARCHAR2(20)")) {
    warn "Perhaps, this version of Oracle does not have unicode data types\n"
        ."Unable to create test table ($DBI::errstr)\n"
        ."Tests skiped.\n";
    print "1..0\n";
    exit 0;
}

print "1..$tests\n";

my $cols = 'idx,col1,col2,dt' ;
#my $sstmt = "SELECT idx,utf8_text,utf8_ch,dt FROM $table ORDER BY idx" ;
my $sstmt = "SELECT $cols FROM $table ORDER BY idx" ;

print "preparing $sstmt\n" ;
my $sel_sth = $dbh->prepare($sstmt );
ok(0, $sel_sth, "prepare: $sstmt " );
exit 1 if not $sel_sth;
ok(0, $sel_sth->execute ,'execute select ... empty table' );
ok(0, not ( $sel_sth->fetch() ), 'select ... empty table' );

#my $widechar = "\x{263A}";
my $widechar = "\x{A2}"; #cent sign
my $ord = ord( $widechar );
print "using wide char = '" .nice_string($widechar)."' ord=" .sprintf("hex%x dec:%d",$ord,$ord) ."\n";
my $ustmt = "INSERT into $table( $cols ) values( ?,?,?,sysdate )" ;

#lab: it appears that it is not required to do the explicit csform binding if the database AND
#     client are in wide char mode.... there are probably permutations of database/client
#     setups that require this

#test_nchars( 0 );
test_nchars( 2 ); #ora_csform => (2) SQLCS_NCHAR


exit 0;

BEGIN { $tests = 31 }
END {
#    $dbh->do(qq{ drop table $table }) if $dbh;
}
# end.


sub test_nchars {
   $dbh->do( "delete from $table" );
   my ($csform) = @_; #ora_csform => (2) SQLCS_NCHAR
   my ($idx, $col1, $col2, $dt );
   $idx = 0;
   my $upd_sth = $dbh->prepare( $ustmt );
   ok(0, $upd_sth, "prepare $ustmt" );

   $idx++; $col1 = "asdf"; $col2 = $widechar ."asdf";
   $ord = ord($col2);
   print "ord of col2 is " .sprintf("hex:%x dec:%d",$ord,$ord)."\n" ;
#   print "col1 is utf8 string\n" if utf8::valid($col1); 
#   print "col2 is utf8 string\n" if utf8::valid($col2); 
   my $colnum = 1;
   ok(0, $upd_sth->bind_param( $colnum++ ,$idx ),                       'bind_param idx' );
   print "binding: col1='$col1' col2='" .nice_string($col2) ."'\n" ;
   if ( ! $csform ) {
      print "NOT binding with ora_csform attr\n" ;
      ok(0, $upd_sth->bind_param( $colnum++ ,$col1 ), 'bind_param col1' );
      ok(0, $upd_sth->bind_param( $colnum++ ,$col2 ), 'bind_param col2' );
   } else {
      print "doing an explicit binding with { ora_csform => $csform }\n" ;
      ok(0, $upd_sth->bind_param( $colnum++ ,$col1 ,{ ora_csform => $csform } ), "bind_param col1 { ora_csform => $csform }" );
      ok(0, $upd_sth->bind_param( $colnum++ ,$col2 ,{ ora_csform => $csform } ), "bind_param col2 { ora_csform => $csform }" );
   }
   ok(0,$upd_sth->execute,"execute: $ustmt with bound params" );

   $idx = 0; $col1 = ""; $col2 = ""; $dt = "";
   ok(0,$sel_sth->execute(),'select after one row inserted' );
   $colnum = 1;
   ok(0, $sel_sth->bind_col( $colnum++ ,\$idx ), 'bind_col idx' );
   ok(0, $sel_sth->bind_col( $colnum++ ,\$col1 ), 'bind_col col1' ); # ,{ ora_csform => 2 } ), 'bind_col col ora_csform => (2) SQLCS_NCHAR' );
   ok(0, $sel_sth->bind_col( $colnum++ ,\$col2 ), 'bind_col col2' ); # ,{ ora_csform => 2 } ), 'bind_col nc ora_csform => (2) SQLCS_NCHAR' );
   ok(0, $sel_sth->bind_col( $colnum++ ,\$dt ),   'bind_col dt' );
   my $cnt = 0;
   while ( $sel_sth->fetch() )
   {
       $cnt++;
       ok(0,$idx==1,"retrieved idx");
       ok(0,$col1 eq "asdf","retrieved col1");
       if ( $csform == 0 )
       {
           $ord = ord($col2);
           print "ord($col2) = ".sprintf("hex:%x dec:%d",$ord,$ord)."\n" ;
#           print "col1 is utf8 string\n" if utf8::valid($col1); 
#           print "col2 is utf8 string\n" if utf8::valid($col2); 

           my $cerr = ($col2 =~ m/^\?/ );
           ok(0,$cerr,"why did we not get conversion error for col2 when csform=0" );
           print "cerr=$cerr: col2=$col2\n" ;
       } else {
           $ord = ord($col2);
           print "ord($col2) = ".sprintf("hex:%x dec:%d",$ord,$ord)."\n" ;
#           print "col1 is utf8 string\n" if utf8::valid($col1); 
#           print "col2 is utf8 string\n" if utf8::valid($col2); 

           #print "ord(col2)=".ord($col2)."\n" ;
           if ( nice_string($col2) eq nice_string($widechar."asdf") ) {
               print "idx=$idx col1='$col1' col2='".nice_string($col2)."' dt=$dt\n" ;
               ok(0,1,"retrieved col2");
           } else {
               ok(0,0,"retrieved col2");
           }
       }
   }

   ok(0,$cnt==1,"one row retreived" ); #14
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
    print "$sql\n";
    return 1;
}
#from the perluniintro page:
sub nice_string {
    join("",
    map { $_ > 255 ?                  # if wide character...
          sprintf("\\x{%04X}", $_) :  # \x{...}
          chr($_) =~ /[[:cntrl:]]/ ?  # else if control character ...
          sprintf("\\x%02X", $_) :    # \x..
          chr($_)                     # else as themselves
    } unpack("U*", $_[0]));           # unpack Unicode characters
}

sub ok ($$;$) {
    my($n, $ok, $warn) = @_;
    $warn ||= '';
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    if ($ok) {
	print "ok $t\n";
    }
    else {
	$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
	warn "# failed test $t at line ".(caller)[2].". $warn\n";
	print "not ok $t\n";
	++$failed;
    }
    return $ok;
}

__END__
