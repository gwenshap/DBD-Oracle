#!perl -w

use DBI;
use DBD::Oracle qw(:ora_types ORA_OCI SQLCS_NCHAR );
use strict;
use Test::More;

#
# Search for 'ocibug' to find code related to OCI LONG bugs.
#

my $utf8_test = ($] >= 5.006) && ($ENV{NLS_LANG} && $ENV{NLS_LANG} =~ m/utf8$/i);
my @test_sets ;
if ( 0 ) {
    if ( ORA_OCI >= 8 )
    {
        push @test_sets, [ "BLOB",	ORA_BLOB,	0 ] ;
        push @test_sets, [  "CLOB",	ORA_CLOB,	0 ] ;
        if ( $utf8_test ) {
            push @test_sets, [  "NCLOB",	ORA_CLOB,	0 ] ;
        } else {
            push @test_sets, [  "CLOB",	ORA_CLOB,	0 ] ;
        }
    }
    push @test_sets, [ "LONG",	0 ,		0 ];
    push @test_sets, [ "LONG RAW",	ORA_LONGRAW,	0 ];
}
else
{
    if ( $utf8_test ) {
        push @test_sets, [  "NCLOB",	ORA_CLOB,	0 ] ;
    } else {
        push @test_sets, [  "CLOB",	ORA_CLOB,	0 ] ;
    }
}
#lab sub ok ($$;$);

$| = 1;
my $t = 0;
my $failed = 0;
my %ocibug;
my $table = "dbd_ora__drop_me";



my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';
my $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
	AutoCommit => 1,
	PrintError => 1,
});

unless($dbh) {
    warn "Unable to connect to Oracle ($DBI::errstr)\nTests skipped.\n";
    print "1..0\n";
    exit 0;
}

#print out database character sets from NSL_DATABASE_PARAMETERS:
sub print_nls_info
{
    warn "NLS_LANG=".$ENV{NLS_LANG}."\n";
    my $sth = $dbh->prepare( "select PARAMETER,VALUE from NLS_DATABASE_PARAMETERS where PARAMETER like ?" );
    $sth->execute( '%CHARACTERSET' );
    my ( $value, $param );
    $sth->bind_col( 1 ,\$param );
    $sth->bind_col( 2 ,\$value );
    my $cnt = 0;
    while ( $sth->fetch() ) {
        $cnt++;
        warn "$param=$value\n" ;
    }
    warn "\n";
}



unless(create_table("lng LONG")) {
    warn "Unable to create test table ($DBI::errstr)\nTests skipped.\n";
    print "1..0\n";
    exit 0;
}

sub array_test {
    return 0;	# XXX disabled
    eval {
	$dbh->{RaiseError}=1;
	$dbh->trace(3);
	my $sth = $dbh->prepare_cached(qq{
	   UPDATE $table set idx=idx+1 RETURNING idx INTO ?
	});
	my ($a,$b);
	$a = [];
	$sth->bind_param_inout(1,\$a, 2);
	$sth->execute;
	print "a=$a\n";
	print "a=@$a\n";
    };
    die "RETURNING array: $@";
}

# Set size of test data (in 10KB units)
#	Minimum value 3 (else tests fail because of assumptions)
#	Normal  value 8 (to test 64KB threshold well)
my $sz = 8;

my $tests;
my $tests_per_set = 91;
$tests = @test_sets * $tests_per_set;
plan tests => $tests;
#lab print "1..$tests\n";

my($sth, $p1, $p2, $tmp, @tmp);
#$dbh->trace(4);

foreach (@test_sets) {
    my ($type_name, $type_num, $test_no_type) = @$_;
    #next if $type_name eq 'LONG';
    diag qq(


    Running long test for 
        type_name=$type_name
        type_num=$type_num
        test_no_type=$test_no_type



);
    run_long_tests($type_name, $type_num);
    run_long_tests($type_name, 0) if $test_no_type;
}


sub run_long_tests 
{
    my ($type_name, $type_num) = @_;

    # relationships between these lengths are important # e.g.
    my %long_data;
    my $long_data0 = ("0\177x\0X"   x 2048) x (1    );  # 10KB  < 64KB
    if ($utf8_test) {
        #lab my $utf_x = eval q{ "0\x{263A}xyX" };
        my $utf_x = "0\x{263A}xyX"; #lab: the ubiquitous smiley face
        $long_data0 = ($utf_x x 2048) x (1    );        # 10KB  < 64KB
        if (length($long_data0) > 10240) {
            diag "known bug in perl5.6.0 utf8 support, applying workaround\n";
            #lab my $utf_z = q{ "0\x{263A}xyZ" };
            my $utf_z = "0\x{263A}xyZ" ;
            $long_data0 = $utf_z;
            $long_data0 .= $utf_z foreach (1..2047);
        }
        if ($type_name =~ /BLOB/) {
            # convert string from utf-8 to byte encoding
            $long_data0 = pack "C*", (unpack "C*", $long_data0);
        }
        #} else { #lab
        #    diag "\n\nsetting dbh->{ora_ph_csform} = SQLCS_NCHAR\n\n" ;
        #    $dbh->{ora_ph_csform} = SQLCS_NCHAR;
        #}
    }
    my $long_data1 = ("1234567890"  x 1024) x ($sz  );  # 80KB >> 64KB && > long_data2
    my $long_data2 = ("2bcdefabcd"  x 1024) x ($sz-1);  # 70KB  > 64KB && < long_data1

    # special hack for long_data0 since RAW types need pairs of HEX
    $long_data0 = "00FF" x (length($long_data0) / 2) if $type_name =~ /RAW/i;

    my $len_data0 = length($long_data0);
    my $len_data1 = length($long_data1);
    my $len_data2 = length($long_data2);

    # warn if some of the key aspects of the data sizing are tampered with
    warn "long_data0 is > 64KB: $len_data0\n"
            if $len_data0 > 65535;
    warn "long_data1 is < 64KB: $len_data1\n"
            if $len_data1 < 65535;
    warn "long_data2 is not smaller than $long_data1 ($len_data2 > $len_data1)\n"
            if $len_data2 >= $len_data1;
     

    SKIP: 
    { #it all
        skip "Unable to create test table for '$type_name' data ($DBI::err)." ,$tests_per_set 
            if (!create_table("lng $type_name", 1));
            # typically OCI 8 client talking to Oracle 7 database

        diag "long_data0 length $len_data0\n";
        diag "long_data1 length $len_data1\n";
        diag "long_data2 length $len_data2\n";

        diag " --- insert some $type_name data (ora_type $type_num)\n";
        #lab ok(0, $sth = $dbh->prepare("insert into $table values (?, ?, SYSDATE)"), 1);
        my $sqlstr = "insert into $table values (?, ?, SYSDATE)" ;
        
        ok( $sth = $dbh->prepare( $sqlstr ), "prepare: $sqlstr" ); 
        my $bind_attr =  { ora_type => $type_num };
        $bind_attr->{ora_csform} = SQLCS_NCHAR if $utf8_test and $type_name =~ /NCLOB/ ;

        $sth->bind_param(2, undef, $bind_attr ) or die "$type_name: $DBI::errstr" if $type_num;

        #$sth->trace(3);
        ok($sth->execute(40, $long_data{40} = $long_data0 ), "insert long data 40" );
        ok($sth->execute(41, $long_data{41} = $long_data1 ), "insert long data 41" );
        $sth->trace(0);
        ok($sth->execute(42, $long_data{42} = $long_data2 ), "insert long data 42" );
        ok($sth->execute(43, $long_data{43} = undef), "insert long data undef 43" ); # NULL
        $sth->trace(0);
        array_test();

        diag " --- fetch $type_name data back again -- truncated - LongTruncOk == 1\n";
        $dbh->{LongReadLen} = 20;
        $dbh->{LongTruncOk} =  1;
        diag "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

        # This behaviour isn't specified anywhere, sigh:
        my $out_len = $dbh->{LongReadLen};
        $out_len *= 2 if ($type_name =~ /RAW/i);

        #lab ok(0, $sth = $dbh->prepare("select * from $table order by idx"), 1);
        #lab ok(0, $sth->execute, 1);
        #lab ok(0, $tmp = $sth->fetchall_arrayref, 1);
        $sqlstr = "select * from $table order by idx";
        ok($sth = $dbh->prepare($sqlstr), "prepare: $sqlstr" );
        ok($sth->execute, "execute: $sqlstr" );
        ok($tmp = $sth->fetchall_arrayref, "fetch_arrayerf for $sqlstr" );

        SKIP: {
            if ($DBI::err && $DBI::errstr =~ /ORA-01801:/) {
                # ORA-01801: date format is too long for internal buffer
                skip " If you're using Oracle <= 8.1.7 then this error is probably\n"
                    ." due to an Oracle bug and not a DBD::Oracle problem.\n" , 5 ;
            }
            cmp_ok(@$tmp ,'==' ,4 ,'four rows 5' );
            ok($tmp->[0][1] eq substr($long_data0,0,$out_len),
                    cdif($tmp->[0][1], substr($long_data0,0,$out_len), "Len ".length($tmp->[0][1])) );
            ok($tmp->[1][1] eq substr($long_data1,0,$out_len),
                    cdif($tmp->[1][1], substr($long_data1,0,$out_len), "Len ".length($tmp->[1][1])) );
            ok($tmp->[2][1] eq substr($long_data2,0,$out_len),
                    cdif($tmp->[2][1], substr($long_data2,0,$out_len), "Len ".length($tmp->[2][1])) );
            # use Data::Dumper; print Dumper($tmp->[3]);
            ok(!defined $tmp->[3][1], "last row undefined"); # NULL # known bug in DBD::Oracle <= 1.13
        }

        diag " --- fetch $type_name data back again -- truncated - LongTruncOk == 0\n";
        $dbh->{LongReadLen} = $len_data1 - 10; # so $long_data0 fits but long_data1 doesn't
        $dbh->{LongReadLen} = $dbh->{LongReadLen} / 2 if $type_name =~ /RAW/i;
        my $LongReadLen = $dbh->{LongReadLen};
        $dbh->{LongTruncOk} = 0;
        diag "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

        $sqlstr = "select * from $table order by idx";
        ok($sth = $dbh->prepare($sqlstr), "prepare $sqlstr" );
        ok($sth->execute, "execute $sqlstr" );

        ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref $sqlstr" );
        ok($tmp->[1] eq $long_data0, "length tmp->[1] ".length($tmp->[1]) );

        { 
            local $sth->{PrintError} = 0;
            ok(!defined $sth->fetchrow_arrayref,
                    "truncation error not triggered "
                    ."(LongReadLen $LongReadLen, data ".length($tmp->[1]||0).")");
            $tmp = $sth->err || 0;
            ok( ($tmp == 1406 || $tmp == 24345) ,"tmp==1406 || tmp==24345 tmp actually=$tmp" );
        }


        diag " --- fetch $type_name data back again -- complete - LongTruncOk == 0\n";
        $dbh->{LongReadLen} = $len_data1 +1000;
        $dbh->{LongTruncOk} = 0;
        diag "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

        $sqlstr = "select * from $table order by idx";
        ok($sth = $dbh->prepare($sqlstr), "prepare: $sqlstr" );
        #$sth->trace(4);
        ok($sth->execute, "execute $sqlstr" );

        ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref $sqlstr" );
        ok($tmp->[1] eq $long_data0, "length of tmp->[1] == " .length($tmp->[1]) );

        ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref $sqlstr" );
        ok($tmp->[1] eq $long_data1,"length of tmp->[1] == " . length($tmp->[1]) );

        ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref $sqlstr" );
        if ($tmp->[1] eq $long_data2) {
            ok(1 ,"tmp->[1] eq long_data2" );
        }
        elsif (length($tmp->[1]) == length($long_data1)
           && DBD::Oracle::ORA_OCI() == 7
           && substr($tmp->[1], 0, length($long_data2)) eq $long_data2
        ) {
          diag "OCI7 buffer overwite bug detected\n";
          $ocibug{LongReadLen} = __LINE__;	# see also blob_read tests below
            # The bug:
            #	If you fetch a LONG field and then fetch another row
            #	which has a LONG field shorter than the previous
            #	then the second long will appear to have the
            #	longer portion of first appended to it!
          ok(1, "OCI7buffer overwite bug detected" );
        }
        else {
          ok($tmp->[1] eq $long_data2,
                cdif($tmp->[1],$long_data2, "Len ".length($tmp->[1])) );
        }
        $sth->trace(0);


        SKIP: {
            skip( "blob_read tests for LONGs with OCI8 - not currently supported.\n" ,11 )
                if (ORA_OCI >= 8 && $type_name =~ /LONG/i) ;

            #$dbh->trace(4);
            diag "\n\n--- fetch $type_name data back again -- via blob_read\n\n";

            $dbh->{LongReadLen} = 1024 * 90;
            $dbh->{LongTruncOk} =  1;
            $sqlstr = "select * from $table order by idx";
            ok($sth = $dbh->prepare($sqlstr) ,"prepare $sqlstr" );
            ok($sth->execute, "execute $sqlstr" );
            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 1: $sqlstr"  );

            cmp_ok(blob_read_all($sth, 1, \$p1, 4096) ,'==', length($long_data0), "blob_read_all = length(\$long_data0)" );
            ok($p1 eq $long_data0, cdif($p1, $long_data0) );

            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 2: $sqlstr" );
            cmp_ok(blob_read_all($sth, 1, \$p1, 12345) ,'==', length($long_data1), "blob_read_all = length(long_data1)" );
            ok($p1 eq $long_data1, cdif($p1, $long_data1) );

            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 3: $sqlstr"  );
            my $len = blob_read_all($sth, 1, \$p1, 34567);

            SKIP: {
                if ($len == length($long_data1)
                   && DBD::Oracle::ORA_OCI() == 7
                   && substr($p1, 0, length($long_data2)) eq $long_data2
                ) {
                    #print "OCI7 buffer overwite bug detected\n";
                    $ocibug{blob_read} = __LINE__;	# see also blob_read tests below
                    # The bug:
                    #	If you use blob_read to read a LONG field and then fetch another row
                    #	and use blob_read to read that LONG field,
                    # 	If the second LONG is shorter than the first
                    #	then the second long will appear to have the
                    #	longer portion of first appended to it.
                    skip "OCI7 buffer overwite bug detected" ,2;
                } else {
                    cmp_ok($len,'==', length($long_data2), "length of long_data2 = $len" );
                    ok($p1 eq $long_data2, cdif($p1, $long_data2) ); # Oracle may return the right length but corrupt the string.
                }
            } #skip 2 
        } #skip 11


        SKIP: {
            skip( "ORA_OCI < 8 && $type_name =~ /LOB/i" ,1+(13*4) ) if not ( ORA_OCI >= 8 && ($type_name =~ /LOB/i) );

            diag "\n --- testing ora_auto_lob to access $type_name LobLocator\n\n";
            $sqlstr = qq{
                    SELECT lng, idx FROM $table ORDER BY idx
                    FOR UPDATE -- needed so lob locator is writable
                };
            my $ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents
            ok($ll_sth ,"prepare $sqlstr" );
            ok($ll_sth->execute ,"execute $sqlstr" );
            my $data_fmt = "%03d foo!";

            while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                diag "$idx: ".DBI::neat($lob_locator)."\n";
                next if !defined($lob_locator) && $idx == 43;

                ok($lob_locator, "lob_locator false");
                is(ref $lob_locator , 'OCILobLocatorPtr', 'ref $lob_locator' );
                ok( (ref $lob_locator and $$lob_locator), "lob_locator deref ptr false" ) ;
                my $data = sprintf $data_fmt, $idx;
                ok($dbh->func($lob_locator, 1, $data, 'ora_lob_write') ,"ora_lob_write" ); #lab: is this trashing things?
            }
            #$dbh->commit;
            #$ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents
            #diag "RE prepare: $sqlstr\n" ;
            ok($ll_sth->execute,"execute (again 1) $sqlstr" );
            while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                diag "$idx locator: ".DBI::neat($lob_locator)."\n";
                #next if !defined($lob_locator) && $idx == 43;
                SKIP: {
                    skip "long_data{idx} not ndefined" ,7 if ! defined $long_data{$idx};

                    diag "DBI::errstr=$DBI::errstr\n" if $DBI::err ;
                $dbh->trace(3) if $utf8_test; #look here
                    my $content = $dbh->func($lob_locator, 1, 20, 'ora_lob_read');
                $dbh->trace(0);
                    diag "DBI::errstr=$DBI::errstr\n" if $DBI::err ;
                    ok($content,"content is true" );
                    diag "$idx content: ".DBI::neat($content)."\n";
                    cmp_ok(length($content) ,'==', 20 ,"lenth(content)" );

                    # but prefix has been overwritten:
                    my $data = sprintf $data_fmt, $idx;
                    ok(substr($content,0,length($data)) eq $data ,"content=data" );

                    # ora_lob_length agrees:
                    my $len = $dbh->func($lob_locator, 'ora_lob_length');
                    ok(!$DBI::err ,"DBI::errstr" );
                    cmp_ok($len ,'==', length($long_data{$idx}) ,"len($len)=length(long_data{idx})" );

                    # now trim the length
                    $dbh->func($lob_locator, $idx, 'ora_lob_trim');
                    ok(!$DBI::err, "DBI::errstr" );

                    # and append some text
                    $dbh->func($lob_locator, "12345", 'ora_lob_append');
                    ok(!$DBI::err ,"DBI::errstr" );
                    if ($DBI::err && $DBI::errstr =~ /ORA-24801:/) {
                        warn " If you're using Oracle < 8.1.7 then the OCILobWriteAppend error is probably\n";
                        warn " due to Oracle bug #886191 and is not a DBD::Oracle problem\n";
                        --$failed; # don't trigger long message below just for this
                    }
                }
            }
            diag "round again to check the length...\n";
            ok($ll_sth->execute ,"excute (again 2) $sqlstr" );
            while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                diag "$idx locator: ".DBI::neat($lob_locator)."\n";
                SKIP: {
                    skip "lob_locator not defined" ,2 if not defined $lob_locator;
                    my $len = $dbh->func($lob_locator, 'ora_lob_length');
                    #lab: possible logic error here w/resp. to len
                    ok(!$DBI::err ,"DBI::errstr" );
                    cmp_ok( $len ,'==', $idx + 5 ,"len == idx+5" );
                }
            }
            ok(1);
        } #skip ORA_OCI < 8

        #die $DBI::errstr;# if $DBI::err;
    } #skip it all (tests_per_set)
} # end of run_long_tests

if (%ocibug) {
	my @lines = sort values %ocibug;
    warn "\n\aYour version of Oracle 7 OCI has a bug that affects fetching LONG data.\n";
    warn "See the t/long.t script near lines @lines for more information.\n";
    warn "You can safely ignore this if: You don't fetch data from LONG fields;\n";
    warn "Or the LONG data you fetch is never longer than 65535 bytes long;\n";
    warn "Or you only fetch one LONG record in the life of a statement handle.\n";
}

if ($failed > 0) {
    warn "\nSome tests for LONG data type handling failed. These are generally Oracle bugs.\n";
    warn "Please report this to the dbi-users mailing list, and include the\n";
    warn "Oracle version number of both the client and the server.\n";
    warn "Please also include the output of the 'perl -V' command.\n";
    warn "(If you can, please study t/long.t to investigate the cause.\n";
    warn "Feel free to edit the tests to see what's happening in more detail.\n";
    warn "Especially by adding trace() calls around the failing tests.\n";
    warn "Run the tests manually using the command \"perl -Mblib t/long.t\")\n";
    warn "Meanwhile, if the other tests have passed you can use DBD::Oracle.\n\n";
    print_nls_info();
    warn "\n";
}

sleep 6 if $failed || %ocibug;

exit 0;
BEGIN { $tests = 27 }
END {
    $dbh->do(qq{ drop table $table }) if $dbh and not $ENV{DBD_SKIP_TABLE_DROP};
}
# end.


# ----

sub create_table {
    my ($fields, $drop) = @_;
    my $sql = "create table $table ( idx integer, $fields, dt date )";
    $dbh->do(qq{ drop table $table }) if $drop;
    diag "\n\ndrop table $table\n" if $drop;
    $dbh->do($sql);
    if ($dbh->err && $dbh->err==955) {
	$dbh->do(qq{ drop table $table });
	warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
	$dbh->do($sql);
    }
    return 0 if $dbh->err;
    diag "\n\n$sql\n\n\n\n";
    return 1;
}

sub blob_read_all {
    my ($sth, $field_idx, $blob_ref, $lump) = @_;

    $lump ||= 4096; # use benchmarks to get best value for you
    my $offset = 0;
    my @frags;
    while (1) {
        #$sth->trace(3);
	my $frag = $sth->blob_read($field_idx, $offset, $lump);
        $sth->trace(0);
	#lab return unless defined $frag;
	last unless defined $frag;
	my $len = length $frag;
	last unless $len;
	push @frags, $frag;
	$offset += $len;
	#warn "offset $offset, len $len\n";
    }
    $$blob_ref = join "", @frags;
    return length($$blob_ref);
}

sub unc {
    my @str = @_;
    foreach (@str) { s/([\000-\037\177-\377])/ sprintf "\\%03o", ord($_) /eg; }
    return join "", @str unless wantarray;
    return @str;
}

sub cdif {
    my ($s1, $s2, $msg) = @_;
    $msg = ($msg) ? ", $msg" : "";
    my ($l1, $l2) = (length($s1), length($s2));
    return "Strings are identical$msg" if $s1 eq $s2;
    return "Strings are of different lengths ($l1 vs $l2)$msg" # check substr matches?
	if $l1 != $l2;
    my $i;
    for($i=0; $i < $l1; ++$i) {
	my ($c1,$c2) = (ord(substr($s1,$i,1)), ord(substr($s2,$i,1)));
	next if $c1 == $c2;
        return sprintf "Strings differ at position %d (\\%03o vs \\%03o)$msg",
		$i,$c1,$c2;
    }
    return "(cdif error $l1/$l2/$i)";
}


#lab sub ok ($$;$) {
#lab     my($n, $ok, $warn) = @_;
#lab     $warn ||= '';
#lab     ++$t;
#lab     die "sequence error, expected $n but actually $t"
#lab     if $n and $n != $t;
#lab     if ($ok) {
#lab 	print "ok $t\n";
#lab     }
#lab     else {
#lab 	$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq '1';
#lab 	warn "# failed test $t at line ".(caller)[2].". $warn\n";
#lab 	print "not ok $t\n";
#lab 	++$failed;
#lab     }
#lab     return $ok;
#lab }


__END__
