use strict;
use warnings;
use Carp;
use Data::Dumper;
use DBI;
use DBD::Oracle qw(ORA_OCI);

require utf8;

# perl 5.6 doesn't define utf8::is_utf8()
unless (defined &{"utf8::is_utf8"}) {
    die "Can't run tests using Perl $] without DBI >= 1.38"
	unless $DBI::VERSION >= 1.38;
    *utf8::is_utf8 = sub {
	my $raw = shift;
	return 0 if !defined $raw;
	my $v = DBI::neat($raw);
	return 1 if $v =~ /^"/; # XXX ugly hack, sufficient here
	return 0 if $v =~ /^'/; # XXX ugly hack, sufficient here
	carp "Emulated utf8::is_utf8 is unreliable for $v ($raw)";
	return 0;
    }
}

=head binmode STDOUT, ':utf8'

 Wide character in print at t/nchar_test_lib.pl line 134 (#1)
    (W utf8) Perl met a wide character (>255) when it wasn't expecting
    one.  This warning is by default on for I/O (like print).  The easiest
    way to quiet this warning is simply to add the :utf8 layer to the
    output, e.g. binmode STDOUT, ':utf8'.  Another way to turn off the
    warning is to add no warnings 'utf8'; but that is often closer to
    cheating.  In general, you are supposed to explicitly mark the
    filehandle with an encoding, see open and perlfunc/binmode.
=cut
eval { binmode STDOUT, ':utf8' }; # Fails for perl 5.6
print "Can't set binmode(STDOUT, ':utf8'): $@" if $@;

sub long_test_cols
{
   my ($type) = @_ ;
   return 
   [
      [ lng => $type ],
   ];
}
sub char_cols
{
    [ 
        [ ch    => 'varchar2(20)' ],
        [ descr => 'varchar2(50)' ],
    ];
}
sub nchar_cols
{
    [ 
        [ nch   => 'nvarchar2(20)' ],
        [ descr => 'varchar2(50)' ],
    ];
}
sub wide_data
{
    [
        [ "\x{03}",   "control-C"        ], 
        [ "a",        "lowercase a"      ],
        [ "b",        "lowercase b"      ],
        [ "\x{263A}", "smiley face"      ],
# These are not safe for db's with US7ASCII
#       [ "\x{A1}", "upside down bang" ],
#       [ "\x{A2}", "cent char"        ],
#       [ "\x{A3}", "brittish pound"   ],
    ];
}
sub extra_wide_rows
{
   # Non-BMP characters require use of surrogates with UTF-16
   # So U+10304 becomes U+D800 followed by U+DF04 (I think) in UTF-16.
   #
   # When encoded as standard UTF-8, which Oracle calls AL32UTF8, it should
   # be a single UTF-8 code point (that happens to occupy 4 bytes).
   #
   # When encoded as "CESU-8", which Oracle calls "UTF8", each surrogate
   # is treated as a code point so you get 2 UTF-8 code points
   # (that happen to occupy 3 bytes each). That is not valid UTF-8.
   # See http://www.unicode.org/reports/tr26/ for more information.
   return unless ORA_OCI >= 9.2; # need AL32UTF8 for these to work
   return (  
      [ "\x{10304}", "SMP Plane 1 wide char"  ], # OLD ITALIC LETTER E
      [ "\x{20301}", "SIP Plane 2 wide char"  ], # CJK Unified Ideographs Extension B
   );
}
sub narrow_data 	# Assuming WE8ISO8859P1 or WE8MSWIN1252 character set 
{
    [
        [ chr(3),   "control-C"        ],
        [ "a",      "lowercase a"      ],
        [ "b",      "lowercase b"      ],
        [ chr(161), "upside down bang" ],
        [ chr(162), "cent char"        ],
        [ chr(163), "brittish pound"   ],
    ];
}

my $tdata_hr = {
    narrow_char => {
        cols => char_cols(),
        rows => narrow_data()
    }
    ,
    narrow_nchar => {
        cols => nchar_cols(),
        rows => narrow_data()
    }
    ,
    wide_char => {
        cols => char_cols(),
        rows => wide_data()
    }
    ,
    wide_nchar => {
        cols => nchar_cols(),
        rows => wide_data()
    }
    ,
};
sub test_data
{
    my ($which) = @_;
    return $tdata_hr->{$which};
}

sub db_handle
{

    my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
    my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
        AutoCommit => 1,
        PrintError => 1,
        ora_envhp  => 0,
    });
    return $dbh;
}
sub show_test_data
{
    my ($tdata) = @_;
    my $rowsR = $tdata->{rows};
    my $cnt = 0;
    my $vcnt = 0;
    foreach my $recR ( @$rowsR )
    {
        $cnt++;
	my $v = $$recR[0];
        my $byte_string = byte_string($v);
        my $nice_string = nice_string($v);
        printf( "row: %3d: nice_string=%s byte_string=%s (%s, %s)\n",
                $cnt, $nice_string, $byte_string, $v, DBI::neat($v));
    }
    return $cnt;
}

sub table { 'dbd_ora__drop_me' ; }
sub drop_table
{
    my ($dbh) = @_;
    my $table = table();
    local $dbh->{PrintError} = 0;
    $dbh->do(qq{ drop table $table });
}

sub insert_handle 
{
    my ($dbh,$tcols) = @_;
    my $table = table();
    my $sql = "insert into $table ( idx, ";
    my $cnt = 1;
    foreach my $col ( @$tcols )
    {
        $sql .= $$col[0] . ", ";
        $cnt++;
    }
    $sql .= "dt ) values( " . "?, " x $cnt ."sysdate )";
    my $h = $dbh->prepare( $sql );
    ok( $h ,"prepared: $sql" );
    return $h;
}
sub insert_test_count
{
    my ( $tdata ) = @_;
    my $rcnt = @{$tdata->{rows}};
    my $ccnt = @{$tdata->{cols}};
    return 1 + $rcnt*2 + $rcnt * $ccnt;
}
sub insert_rows #1 + rows*2 +rows*ncols tests
{
    my ($dbh, $tdata ,$csform) = @_;
    my $trows = $tdata->{rows};
    my $tcols = $tdata->{cols};
    my $table = table();
    # local $dbh->{TraceLevel} = 4;
    my $sth = insert_handle($dbh, $tcols);

    my $cnt = 0;
    foreach my $rowR ( @$trows )
    {
        my $colnum = 1;
        my $attrR = $csform ? { ora_csform => $csform } : {};
        ok(  $sth->bind_param( $colnum++ ,$cnt ) ,"bind_param idx" );
        for( my $i = 0; $i < @$rowR; $i++ )
        {
            my $note = 'withOUT attribute ora_csform';
            my $val = $$rowR[$i];
            my $type = $$tcols[$i][1];
            #print "type=$type\n";
            my $attr = {};
            if ( $type =~ m/^nchar|^nvar|^nclob/i ) 
            {
                $attr = $attrR;
                $note = $attr && $csform ? "with attribute { ora_csfrom => $csform }" : "";
            } 
            ok( $sth->bind_param( $colnum++ ,$val ,$attr ) ,"bind_param " . $$tcols[$i][0] ." $note" );
        }
        $cnt++;
        ok( $sth->execute ,"insert row $cnt: $rowR->[-1]" );
    }
}
sub dump_table
{
    my ( $dbh ,@cols ) = @_;
    my $table = table();
    my $colstr = '';
    foreach my $col ( @cols ) {
        $colstr .= ", " if $colstr;
        $colstr .= "dump($col)"
    }
    my $sql = "select $colstr from $table order by idx" ;
    my $sth = $dbh->prepare( $sql );
    print "dumping $table\nprepared: $sql\n" ;
    my $colnum = 0;
    my @data = ();;
    $sth->execute();
    my $cnt = 0;
    while ( my $aref = $sth->fetchrow_arrayref() ) {
        $cnt++;
        my $colnum = 0;
        foreach my $col ( @cols ) {
            print "row $cnt: " ; 
            print "$col=" .$$aref[$colnum] ."\n";
            $colnum++;
        }
    }
}
sub select_handle #1 test
{
    my ($dbh,$tdata) = @_;
    my $table = table();
    my $sql = "select ";
    foreach my $col ( @{$tdata->{cols}} )
    {
        $sql .= $$col[0] . ", ";
    }
    $sql .= "dt from $table order by idx" ;
    my $h = $dbh->prepare( $sql );
    ok( $h ,"prepared: $sql" );
    return $h;
}
sub select_test_count 
{
    my ( $tdata ) = @_;
    my $rcnt = @{$tdata->{rows}};
    my $ccnt = @{$tdata->{cols}};
    return 2 + $ccnt + $rcnt * $ccnt * 2;
}
sub select_rows # 1 + numcols + rows * cols * 2
{
    my ($dbh,$tdata,$csform) = @_;
    my $table = table();
    my $trows = $tdata->{rows};
    my $tcols = $tdata->{cols};
    my $sth = select_handle($dbh,$tdata);
    my @data = ();
    my $colnum = 0;
    foreach my $col ( @$tcols )
    {
        ok( $sth->bind_col( $colnum+1 ,\$data[$colnum] ), "bind column " .$$tcols[$colnum][0] );
        $colnum++;
    }
    my $cnt = 0;
    $sth->execute();
    while ( $sth->fetch() )
    {
        for( my $i = 0 ; $i < @$tcols; $i++ )
        {
            my $res = $data[$i];
	    my $charname = $trows->[$cnt][1] || '';
            my $is_utf8 = utf8::is_utf8( $res ) ? " (uft8)" : "";
	    my $description = "row $cnt; column: $tcols->[$i][0] $is_utf8 $charname";

            cmp_ok( byte_string($res), 'eq', byte_string($$trows[$cnt][$i]),
		"byte_string test of $description"
	    );
	    cmp_ok( nice_string($res), 'eq', nice_string($$trows[$cnt][$i] ),
		"nice_string test of $description"
	    );
            #$sth->trace(0) if $cnt >= 3 ;
        }
        $cnt++;
    }
    #$sth->trace(0);
    my $trow_cnt = @$trows;
    cmp_ok( $cnt, '==', $trow_cnt, "number of rows fetched" );
}
sub create_table 
{
    my ($dbh,$tdata,$drop) = @_;
    my $tcols = $tdata->{cols};
    my $table = table();
    my $sql = "create table $table ( idx integer, ";
    foreach my $col ( @$tcols )
    {
        $sql .= $$col[0] . " " .$$col[1] .", ";
    }
    $sql .= " dt date )";

    drop_table( $dbh ) if $drop;
    #$dbh->do(qq{ drop table $table }) if $drop;
    $dbh->do($sql);
    if ($dbh->err && $dbh->err==955) {
        $dbh->do(qq{ drop table $table });
        warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
        $dbh->do($sql);
    } else {
       #$sql =~ s/ \( */(\n\t/g;
       #$sql =~ s/, */,\n\t/g;
       print "$sql\n" ;
    }
    return 1;
#    ok( not $dbh->err, "create table $table..." );
}



sub show_db_charsets
{
    my ( $dbh ) = @_;
    my $paramsH = $dbh->ora_nls_parameters();
    printf "Database CHAR set is %s (%s), NCHAR set is %s (%s)\n",
	$paramsH->{NLS_CHARACTERSET}, 
	db_ochar_is_utf($dbh) ? "Unicode" : "Non-Unicode",
	$paramsH->{NLS_NCHAR_CHARACTERSET},
	db_nchar_is_utf($dbh) ? "Unicode" : "Non-Unicode";
    printf "Client NLS_LANG is '%s', NLS_NCHAR is '%s'\n",
	$ENV{NLS_LANG} || "<unset>", $ENV{NLS_NCHAR} || "<unset>";
}
sub db_ochar_is_utf { return shift->ora_can_unicode & 2 }
sub db_nchar_is_utf { return shift->ora_can_unicode & 1 }

sub client_ochar_is_utf8 {
   my $NLS_LANG = $ENV{NLS_LANG} || '';
   $NLS_LANG =~ s/.*\.//;
   return $NLS_LANG =~ m/utf8/i;
}
sub client_nchar_is_utf8 {
   my $NLS_LANG = $ENV{NLS_LANG} || '';
   $NLS_LANG =~ s/.*\.//;
   my $NLS_NCHAR = $ENV{NLS_NCHAR} || $NLS_LANG;
   return $NLS_NCHAR =~ m/utf8/i;
}

sub nls_local_has_utf8
{
   return client_ochar_is_utf8() || client_nchar_is_utf8();
}

sub set_nls_nchar
{
    my ($cset,$verbose) = @_;
    if ( defined $cset ) {
        $ENV{NLS_NCHAR} = "$cset"
    } else {
        undef $ENV{NLS_NCHAR};
    }
    print defined $ENV{NLS_NCHAR} ?
        "set \$ENV{NLS_NCHAR}=$cset\n" :
        "set \$ENV{NLS_LANG}=undef\n"
            if defined $verbose;
}

sub set_nls_lang_charset
{
    my ($lang,$verbose) = @_;
    if ( $lang ) {
        $ENV{NLS_LANG} = "AMERICAN_AMERICA.$lang";
        print "set \$ENV{NLS_LANG}=AMERICAN_AMERICA.$lang\n" if ( $verbose );
    } else {
        $ENV{NLS_LANG} = "";
        print "set \$ENV{NLS_LANG}=''\n" if ( $verbose );
    }
}

sub byte_string {
    my $ret = join( "|" ,unpack( "C*" ,$_[0] ) );
    return $ret;
}
sub nice_string {
    my @raw_chars = (utf8::is_utf8($_[0]))
	? unpack("U*", $_[0])		# unpack unicode characters
	: unpack("C*", $_[0]);		# not unicode, so unpack as bytes
    my @chars = map {
	$_ > 255 ?                    # if wide character...
          sprintf("\\x{%04X}", $_) :  # \x{...}
          chr($_) =~ /[[:cntrl:]]/ ?  # else if control character ...
          sprintf("\\x%02X", $_) :    # \x..
          chr($_)                     # else as themselves
    } @raw_chars;
   
   foreach my $c ( @chars )
   {
      if ( $c =~ m/\\x\{08(..)}/ ) {
         $c .= "='" .chr(hex($1)) ."'";
      }
   }
   my $ret = join("",@chars); 

}


sub view_with_sqlplus
{
    my ( $use_nls_lang ,$tdata ) = @_ ;
    my $table = table();
    my $tcols = $tdata->{cols};
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



1;

