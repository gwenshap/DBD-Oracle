#!perl -w
# vim:ts=8:sw=4

use DBI;
use DBD::Oracle qw(:ora_types SQLCS_NCHAR );
use strict;
use Test::More;

my $utf8_test = (($] >= 5.006) && ($ENV{NLS_LANG} && $ENV{NLS_LANG} =~ m/utf8$/i)) ? 1 : 0;

my @test_sets;
#push @test_sets, [ "LONG",	0,		0 ];
#push @test_sets, [ "LONG RAW",	ORA_LONGRAW,	0 ];
warn "LONG tests disabled for now";
push @test_sets, [ "NCLOB",	ORA_CLOB,	0 ] ;
push @test_sets, [ "BLOB",	ORA_BLOB,	0 ] ;
push @test_sets, [ "CLOB",	ORA_CLOB,	0 ] ;

$| = 1;
my $t = 0;
my $table = "dbd_ora__drop_me";



my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

#print out database character sets from NSL_DATABASE_PARAMETERS:
sub print_nls_info
{
    my $dbh = shift;

    diag "\tClient NLS_LANG=".$ENV{NLS_LANG}."\n";
    my $sth = $dbh->prepare( "select PARAMETER,VALUE from NLS_DATABASE_PARAMETERS where PARAMETER like ?" );
    $sth->execute( '%CHARACTERSET' );
    my ( $value, $param );
    $sth->bind_col( 1 ,\$param );
    $sth->bind_col( 2 ,\$value );
    while ( $sth->fetch() ) {
        diag "\tServer $param=$value\n" ;
    }
    warn "\n";
}



sub array_test {
    my ($dbh) = @_;
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
#	Normal  value 8 (to test old 64KB threshold well)
my $sz = 8;

my $tests_per_set = 91;
my $tests = @test_sets * $tests_per_set;
plan tests => $tests;
#lab print "1..$tests\n";

my($p1, $p2, $tmp, @tmp);

foreach (@test_sets) {
    my ($type_name, $type_num, $test_no_type) = @$_;
    #next if $type_name eq 'LONG';
    diag qq(
    =========================================================================
    Running long test for $type_name ($type_num) utf8_test=$utf8_test
);
    run_long_tests($type_name, $type_num);
    run_long_tests($type_name, 0) if $test_no_type;
}


sub run_long_tests 
{
    my ($type_name, $type_num) = @_;

    # relationships between these lengths are important # e.g.
    my %long_data;
    my $long_data2 = ("2bcdefabcd"  x 1024) x ($sz-1);  # 70KB  > 64KB && < long_data1
    my $long_data1 = ("1234567890"  x 1024) x ($sz  );  # 80KB >> 64KB && > long_data2
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
     
    my ($dbh, $sth);

    SKIP: 
    { #it all

	ok $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
		AutoCommit => 1,
		PrintError => 1,
	});
	skip "Unable to connect to database" unless $dbh;

	print_nls_info($dbh);

        skip "Unable to create test table for '$type_name' data ($DBI::err)." ,$tests_per_set 
            if (!create_table($dbh, "lng $type_name", 1));
            # typically OCI 8 client talking to Oracle 7 database

        diag "long_data0 length $len_data0\n";
        diag "long_data1 length $len_data1\n";
        diag "long_data2 length $len_data2\n";

        diag " --- insert some $type_name data (ora_type $type_num)\n";
        #lab ok(0, $sth = $dbh->prepare("insert into $table values (?, ?, SYSDATE)"), 1);
        my $sqlstr = "insert into $table values (?, ?, SYSDATE)" ;
        
        ok( $sth = $dbh->prepare( $sqlstr ), "prepare: $sqlstr" ); 
        my $bind_attr = { ora_type => $type_num };
        $bind_attr->{ora_csform} = SQLCS_NCHAR
		if $type_name =~ /NCLOB/ ;
		#if $utf8_test and $type_name =~ /NCLOB/ ;

        $sth->bind_param(2, undef, $bind_attr )
		or die "$type_name: $DBI::errstr" if $type_num;

        #$sth->trace(3);
        ok($sth->execute(40, $long_data{40} = $long_data0 ), "insert long data 40" );
        ok($sth->execute(41, $long_data{41} = $long_data1 ), "insert long data 41" );
        $sth->trace(0);
        ok($sth->execute(42, $long_data{42} = $long_data2 ), "insert long data 42" );
        ok($sth->execute(43, $long_data{43} = undef), "insert long data undef 43" ); # NULL
        $sth->trace(0);
        array_test($dbh);

        diag " --- fetch $type_name data back again -- truncated - LongTruncOk == 1\n";
        $dbh->{LongReadLen} = 20;
        $dbh->{LongTruncOk} =  1;
        diag "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

        # This behaviour isn't specified anywhere, sigh:
        my $out_len = $dbh->{LongReadLen};
        $out_len *= 2 if ($type_name =~ /RAW/i);

        $sqlstr = "select * from $table order by idx";
        ok($sth = $dbh->prepare($sqlstr), "prepare: $sqlstr" );
	skip "Can't continue" unless $sth;
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
        else {
          ok($tmp->[1] eq $long_data2,
                cdif($tmp->[1],$long_data2, "Len ".length($tmp->[1])) );
        }
        $sth->trace(0);


        SKIP: {
            skip( "blob_read tests for LONGs - not currently supported.\n", 11 )
                if ($type_name =~ /LONG/i) ;

            #$dbh->trace(4);
            diag "\n\n--- fetch $type_name data back again -- via blob_read\n\n";

            $dbh->{LongReadLen} = 1024 * 90;
            $dbh->{LongTruncOk} =  1;
            $sqlstr = "select idx, lng, dt from $table order by idx";
#local $dbh->{TraceLevel} = 9;
            ok($sth = $dbh->prepare($sqlstr) ,"prepare $sqlstr" );
            ok($sth->execute, "execute $sqlstr" );
#$sth->bind_col(2, \my $dummy, { ora_csform => SQLCS_NCHAR }) if $type_name =~ /NCLOB/;

	    print "fetch via fetchrow_arrayref\n";
            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 1: $sqlstr"  );
            ok($tmp->[1] eq $long_data0, cdif($tmp->[1], $long_data0) );

# skip for now at least XXX
skip "blob_read tests for NCLOB not currently supported", 8
    if $type_name =~ /NCLOB/;

	    print "read via blob_read_all\n";
            cmp_ok(blob_read_all($sth, 1, \$p1, 4096) ,'==', length($long_data0), "blob_read_all = length(\$long_data0)" );
            ok($p1 eq $long_data0, cdif($p1, $long_data0) );
	    $sth->trace(0);

            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 2: $sqlstr" );
            cmp_ok(blob_read_all($sth, 1, \$p1, 12345) ,'==', length($long_data1), "blob_read_all = length(long_data1)" );
            ok($p1 eq $long_data1, cdif($p1, $long_data1) );

            ok($tmp = $sth->fetchrow_arrayref, "fetchrow_arrayref 3: $sqlstr"  );
            my $len = blob_read_all($sth, 1, \$p1, 34567);

	    cmp_ok($len,'==', length($long_data2), "length of long_data2 = $len" );
	    ok($p1 eq $long_data2, cdif($p1, $long_data2) ); # Oracle may return the right length but corrupt the string.
        } #skip 11


        SKIP: {
            skip( "not ($type_name =~ /LOB/i)" ,1+(13*4) )
		if not ( $type_name =~ /LOB/i );

            diag "\n --- testing ora_auto_lob to access $type_name LobLocator\n\n";
            my $data_fmt = "%03d foo!";

            $sqlstr = qq{
                    SELECT lng, idx FROM $table ORDER BY idx
                    FOR UPDATE -- needed so lob locator is writable
                };
            my $ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents
            ok($ll_sth ,"prepare $sqlstr" );
            ok($ll_sth->execute ,"execute $sqlstr" );

            while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                diag "$idx: ".DBI::neat($lob_locator)."\n";
                last if !defined($lob_locator) && $idx == 43;

                ok($lob_locator, "lob_locator false");
                is(ref $lob_locator , 'OCILobLocatorPtr', '$lob_locator is a OCILobLocatorPtr' );
                ok( (ref $lob_locator and $$lob_locator), "lob_locator deref ptr false" ) ;
                my $data = sprintf $data_fmt, $idx;
                print "\nlincoln: could it be that ora_lob_write is the function that is trashing things...\n\n" if $utf8_test;
                $dbh->trace(9) if $utf8_test;
                ok($dbh->func($lob_locator, 1, $data, 'ora_lob_write') ,"ora_lob_write" ); #lab: is this trashing things?
                $dbh->trace(0);

            }
            #$dbh->commit;
            if ( 0 ) {
                my $tsql = "select length(lng),idx from $table order by idx" ;
                my $tsth = $dbh->prepare( $tsql );
                $tsth->execute();
                while ( my ( $l,$i ) = $tsth->fetchrow_array() )
                {
                    last if not defined $l;
                    print "$i: $l\n";
                }
            }
            #diag "RE prepare: $sqlstr\n" ;
            #$ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents
            SKIP: { #28
                if ( $utf8_test ) {
                   diag "ora_lob_read does not work (possibily after ora_lob_write) when charset is utf8 (patches welcome)" ;
                }
                ok($ll_sth->execute,"execute (again 1) $sqlstr" );
                while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                    diag "$idx locator: ".DBI::neat($lob_locator)."\n";
                    #next if !defined($lob_locator) && $idx == 43;
                    SKIP: {
                        skip "long_data{idx} not ndefined" ,7 if ! defined $long_data{$idx};

                        diag "DBI::errstr=$DBI::errstr\n" if $DBI::err ;

                    $dbh->trace(9) if $utf8_test; #look here
                        my $content = $dbh->func($lob_locator, 1, 20, 'ora_lob_read');
                    $dbh->trace(0);
                        diag "DBI::errstr=$DBI::errstr\n" if $DBI::err ;
                        ok($content,"content is true" );
                        diag "$idx content: ".DBI::neat($content)."\n";
                        cmp_ok(length($content) ,'==', 20 ,"lenth(content)" );

                        # but prefix has been overwritten:
                        my $data = sprintf $data_fmt, $idx;
                        ok(substr($content,0,length($data)) eq $data ,"length(content)=length(data)" );

                        # ora_lob_length agrees:
                        my $len = $dbh->func($lob_locator, 'ora_lob_length');
                        ok(!$DBI::err ,"DBI::errstr" );
                        cmp_ok($len ,'==', length($long_data{$idx}) ,"length(long_data{idx}) = length of locator data" );

                        # now trim the length
                        $dbh->func($lob_locator, $idx, 'ora_lob_trim');
                        ok(!$DBI::err, "DBI::errstr" );

                        # and append some text
                        $dbh->func($lob_locator, "12345", 'ora_lob_append');
                        ok(!$DBI::err ,"DBI::errstr" );
                        if ($DBI::err && $DBI::errstr =~ /ORA-24801:/) {
                            warn " If you're using Oracle < 8.1.7 then the OCILobWriteAppend error is probably\n";
                            warn " due to Oracle bug #886191 and is not a DBD::Oracle problem\n";
                        }
                    }
                }
            }
            diag "round again to check the length...\n";
            ok($ll_sth->execute ,"execute (again 2) $sqlstr" );
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
        } #skip for LONG types

    } #skip it all (tests_per_set)

    $sth->finish if $sth;
    $dbh->disconnect if $dbh;

} # end of run_long_tests


exit 0;
END {
    my $dbh = $DBI::lasth or return;
    $dbh = $dbh->{Database} if $dbh->{Database};
    $dbh->do(qq{ drop table $table })
	if $dbh->{Active} and not $ENV{DBD_SKIP_TABLE_DROP};
}
# end.


# ----

sub create_table {
    my ($dbh, $fields, $drop) = @_;
    $dbh->do(qq{ drop table $table }) if $drop;
    diag "\n";
    diag "drop table $table\n" if $drop;
    my $sql = "create table $table ( idx integer, $fields, dt date )";
    $dbh->do($sql);
    if ($dbh->err && $dbh->err==955) {
	$dbh->do(qq{ drop table $table });
	warn "Unexpectedly had to drop old test table '$table'\n" unless $dbh->err;
	$dbh->do($sql);
    }
    return 0 if $dbh->err;
    diag "\n$sql\n\n";
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
	last unless defined $frag;
	my $len = length $frag;
	last unless $len;
	push @frags, $frag;
	$offset += $len;
	#print "blob_read_all: offset $offset, len $len\n";
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


__END__
