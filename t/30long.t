#!perl -w
# vim:ts=8:sw=4

use DBI;
use DBD::Oracle qw(:ora_types SQLCS_NCHAR );
use strict;
use Test::More;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

my $utf8_test ; #= (($] >= 5.006) && ($ENV{NLS_LANG} && $ENV{NLS_LANG} =~ m/utf8$/i)) ? 1 : 0;

my @test_sets;
push @test_sets, [ "LONG",	0,		0 ];
push @test_sets, [ "LONG RAW",	ORA_LONGRAW,	0 ];
#warn "LONG tests disabled for now";
push @test_sets, [ "NCLOB",	ORA_CLOB,	0 ] ;
push @test_sets, [ "BLOB",	ORA_BLOB,	0 ] ;
push @test_sets, [ "CLOB",	ORA_CLOB,	0 ] ;

$| = 1;
my $t = 0;
my $table = table();



my ($dbh);
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

sub array_test {
    my ($dbh) = @_;
    return 0;	# XXX disabled
    eval {
	$dbh->{RaiseError}=1;
	$dbh->trace(0);
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

my $tests_per_set = 82;
my $tests = @test_sets * $tests_per_set;
plan tests => $tests;
#lab print "1..$tests\n";

my($p1, $p2, $tmp, @tmp);

$dbh = db_handle();
show_db_charsets($dbh) if $dbh;

foreach (@test_sets) {
    my ($type_name, $type_num, $test_no_type) = @$_;
    #next if $type_name eq 'LONG';
    $utf8_test = use_utf8_data($dbh,$type_name);
    print qq(
    =========================================================================
    Running long test for $type_name ($type_num) utf8_test=$utf8_test
);
    run_long_tests($type_name, $type_num);
    run_long_tests($type_name, 0) if $test_no_type;
}

sub use_utf8_data
{
    my $want_utf8 = (($] >= 5.006) && ($ENV{NLS_LANG} && $ENV{NLS_LANG} =~ m/utf8$/i)) ? 1 : 0;
    my ( $dbh, $type_name ) = @_;
    #return 0 if not $utf8_test;
    return 1 if ( $type_name =~ m/CLOB/i and db_is_utf8($dbh) and $want_utf8 );
    return 1 if ( $type_name =~ m/NCLOB/i and nchar_is_utf8($dbh) ); #and $want_utf8 );
    return 1 if ( $type_name =~ m/BLOB/i and $want_utf8 );
    return 0;
}
sub run_long_tests 
{
    my ($type_name, $type_num) = @_;
    my ($sth);
    SKIP: 
    { #it all

        #ok $dbh = DBI->connect('dbi:Oracle:', $dbuser, '', {
        #       AutoCommit => 1,
        #       PrintError => 1,
        #});
        skip "Unable to connect to database" unless $dbh;


        # relationships between these lengths are important # e.g.
        my %long_data;
        my $long_data2 = ("2bcdefabcd"  x 1024) x ($sz-1);  # 70KB  > 64KB && < long_data1
        my $long_data1 = ("1234567890"  x 1024) x ($sz  );  # 80KB >> 64KB && > long_data2
        my $long_data0 = ("0\177x\0X"   x 2048) x (1    );  # 10KB  < 64KB
        if ( $utf8_test ) { #use_utf8_data($dbh,$type_name)) { #}
            my $utf_x = "0\x{263A}xyX"; #lab: the ubiquitous smiley face
            $long_data0 = ($utf_x x 2048) x (1    );        # 10KB  < 64KB
            if (length($long_data0) > 10240) {
                diag "known bug in perl5.6.0 utf8 support, applying workaround\n";
                my $utf_z = "0\x{263A}xyZ" ;
                $long_data0 = $utf_z;
                $long_data0 .= $utf_z foreach (1..2047);
            }
            if ($type_name =~ /BLOB/) {
                # convert string from utf-8 to byte encoding
                $long_data0 = pack "C*", (unpack "C*", $long_data0);
            }
            # else  #lab
            #    diag "\n\nsetting dbh->{ora_ph_csform} = SQLCS_NCHAR\n\n" ;
            #    $dbh->{ora_ph_csform} = SQLCS_NCHAR;
            #
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

        my $tdata = {
            cols => long_test_cols( $type_name ),
            rows => []
        };
        

        skip "Unable to create test table for '$type_name' data ($DBI::err)." ,$tests_per_set 
            if (!create_table($dbh, $tdata, 1));
            # typically OCI 8 client talking to Oracle 7 database

        print "long_data0 length $len_data0\n";
        print "long_data1 length $len_data1\n";
        print "long_data2 length $len_data2\n";

        print " --- insert some $type_name data (ora_type $type_num)\n";
        #lab ok(0, $sth = $dbh->prepare("insert into $table values (?, ?, SYSDATE)"), 1);
        my $sqlstr = "insert into $table values (?, ?, SYSDATE)" ;
        
        ok( $sth = $dbh->prepare( $sqlstr ), "prepare: $sqlstr" ); 
        my $bind_attr = { ora_type => $type_num };
        $bind_attr->{ora_csform} = SQLCS_NCHAR
		if $utf8_test; #use_utf8_data($dbh,$type_name);  #$type_name =~ /NCLOB/ and nchar_is_utf8($dbh);
		#if $utf8_test and $type_name =~ /NCLOB/ ;

        $sth->trace(0);
        $sth->bind_param(2, undef, $bind_attr )
		or die "$type_name: $DBI::errstr" if $type_num;

        ok($sth->execute(40, $long_data{40} = $long_data0 ), "insert long data 40" );
        ok($sth->execute(41, $long_data{41} = $long_data1 ), "insert long data 41" );
        ok($sth->execute(42, $long_data{42} = $long_data2 ), "insert long data 42" );
        ok($sth->execute(43, $long_data{43} = undef), "insert long data undef 43" ); # NULL
        $sth->trace(0);
        array_test($dbh);

        print " --- fetch $type_name data back again -- truncated - LongTruncOk == 1\n";
        $dbh->{LongReadLen} = 20;
        $dbh->{LongTruncOk} =  1;
        print "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

        # This behaviour isn't specified anywhere, sigh:
        my $out_len = $dbh->{LongReadLen};
        $out_len *= 2 if ($type_name =~ /RAW/i);

        $sqlstr = "select * from $table order by idx";
        ok($sth = $dbh->prepare($sqlstr), "prepare: $sqlstr" );
	skip "Can't continue" unless $sth;
        ok($sth->execute, "execute: $sqlstr" );
        $sth->trace(0);
        ok($tmp = $sth->fetchall_arrayref, "fetch_arrayerf for $sqlstr" );
        $sth->trace(0);

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

        print " --- fetch $type_name data back again -- truncated - LongTruncOk == 0\n";
        $dbh->{LongReadLen} = $len_data1 - 10; # so $long_data0 fits but long_data1 doesn't
        $dbh->{LongReadLen} = $dbh->{LongReadLen} / 2 if $type_name =~ /RAW/i;
        my $LongReadLen = $dbh->{LongReadLen};
        $dbh->{LongTruncOk} = 0;
        print "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

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


        print " --- fetch $type_name data back again -- complete - LongTruncOk == 0\n";
        $dbh->{LongReadLen} = $len_data1 +1000;
        $dbh->{LongTruncOk} = 0;
        print "LongReadLen $dbh->{LongReadLen}, LongTruncOk $dbh->{LongTruncOk}\n";

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
            skip( "blob_read tests for LONGs - not currently supported", 11 )
                if ($type_name =~ /LONG/i) ;

            #$dbh->trace(4);
            print " --- fetch $type_name data back again -- via blob_read\n\n";

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

            # skip for now at least XXX -- not any more (lab)
            #skip "blob_read tests for NCLOB not currently supported", 8
            #    if $type_name =~ /NCLOB/;

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
            skip( "ora_auto_lob tests for $type_name" ."s - not supported" ,11*4 )
                if not ( $type_name =~ /LOB/i );

            print " --- testing ora_auto_lob to access $type_name LobLocator\n\n";
            my $data_fmt = "%03d foo!";

            $sqlstr = qq{
                    SELECT lng, idx FROM $table ORDER BY idx
                    FOR UPDATE -- needed so lob locator is writable
                };
            my $ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents
            ok($ll_sth ,"prepare $sqlstr" );
            #print_lengths($dbh);

            ok($ll_sth->execute ,"execute $sqlstr" );
            while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                print "$idx: ".DBI::neat($lob_locator)."\n";
                last if !defined($lob_locator) && $idx == 43;

                ok($lob_locator, '$lob_locator is true' );
                is(ref $lob_locator , 'OCILobLocatorPtr', '$lob_locator is a OCILobLocatorPtr' );
                ok( (ref $lob_locator and $$lob_locator), '$lob_locator deref ptr is true' ) ;
                my $data = sprintf $data_fmt, $idx; #create a little data
                #print "\nlincoln: could it be that ora_lob_write is the function that is trashing things...\n\n" if $utf8_test;
                $dbh->trace(0) if $utf8_test;
                print "length of data to be written at offset 1: " .length($data) ."\n" ;
#$dbh->trace(6);
                ok($dbh->func($lob_locator, 1, $data, 'ora_lob_write') ,"ora_lob_write" ); #lab: is this trashing things (I don't see how)
                #ok(1,"skipped ora_lob_write" );
                $dbh->trace(0);

            }
            #$dbh->commit;
            #print_substrs($dbh,12);
            #print_lengths($dbh);
            #diag "RE prepare: $sqlstr\n" ;
            #$ll_sth = $dbh->prepare($sqlstr, { ora_auto_lob => 0 } );  # 0: get lob locator instead of lob contents

            print " --- round again to check contents after lob write updates...\n";
            SKIP: { #28
                if ( $utf8_test ) {
                   #skip "\nora_lob_read does seem to work on second execute when charset is utf8 (patches welcome)" ,28 ;
                }
#$dbh->trace(6);
                ok($ll_sth->execute,"execute (again 1) $sqlstr" );
                while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                    print "$idx locator: ".DBI::neat($lob_locator)."\n";
                    if ( not defined $long_data{$idx} ) {
                        last; #for( my $i=0; $i<7; $i++) { ok(1,"end of loop"); }
                    } else {

                        print "DBI::errstr=$DBI::errstr\n" if $DBI::err ;

#$dbh->trace(6) if $utf8_test; #look here
                        my $content = $dbh->func($lob_locator, 1, 20, 'ora_lob_read');
                        $dbh->trace(0);
#exit(0);
                        print "DBI::errstr=$DBI::errstr\n" if $DBI::err ;
                        ok($content,"content is true" );
                        print "$idx content: ".nice_string($content)."\n"; #.DBI::neat($content)."\n";
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
#$dbh->trace(6) if $utf8_test; 
                } #while
            }
            print " --- round again to check the length...\n";
            SKIP: { #10
                if ( $utf8_test ) {
                   #skip "\nora_lob_read does seem to work on second execute when charset is utf8 (patches welcome)" ,10 ;
                }
               ok($ll_sth->execute ,"execute (again 2) $sqlstr" );
               while (my ($lob_locator, $idx) = $ll_sth->fetchrow_array) {
                   print "$idx locator: ".DBI::neat($lob_locator)."\n";
                   if ( not defined $lob_locator ) {
                      last; # ok(1,"end of loop"); ok(1,"end of loop");
                   } else { #skip "lob_locator not defined" ,2 if not defined $lob_locator;
                       my $len = $dbh->func($lob_locator, 'ora_lob_length');
                       #lab: possible logic error here w/resp. to len
                       ok(!$DBI::err ,"DBI::errstr" );
                       cmp_ok( $len ,'==', $idx + 5 ,"len == idx+5" );
                  }
               }
            }
            #ok(1);
        } #skip for LONG types

        $sth->finish if $sth;
        drop_table( $dbh )

    } #skip it all (tests_per_set)

} # end of run_long_tests

exit 0;
END {
    drop_table( $dbh ) if not $ENV{DBD_SKIP_TABLE_DROP};
    $dbh->disconnect if $dbh;
#    my $dbh = $DBI::lasth or return;
#    $dbh = $dbh->{Database} if $dbh->{Database};
#    $dbh->do(qq{ drop table $table })
#	if $dbh->{Active} and not $ENV{DBD_SKIP_TABLE_DROP};
}
# end.

sub print_substrs
{
    my ($dbh,$len) = @_;
    my $tsql = "select substr(lng,1,$len),idx from $table order by idx" ;
    print "-- prepare: $tsql\n" ;
    my $tsth = $dbh->prepare( $tsql );
    $tsth->execute();
    while ( my ( $d,$i ) = $tsth->fetchrow_array() )
    {
        last if not defined $d;
        print "$i: $d\n";
    }
}

sub print_lengths
{
    my ($dbh) = @_;
    my $tsql = "select length(lng),idx from $table order by idx" ;
    print "-- prepare: $tsql\n" ;
    my $tsth = $dbh->prepare( $tsql );
    $tsth->execute();
    while ( my ( $l,$i ) = $tsth->fetchrow_array() )
    {
        last if not defined $l;
        print "$i: $l\n";
    }
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
