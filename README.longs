Some examples related to the use of LONG types.

For complete working code, take a look at the t/long.t file.

----------------------------------------------------------------------

You must fetch the row before you can fetch the longs associated with
that row.  In other words, use the following alorithm...

   1) login
   2) prepare( select ... )
   3) execute
   4) while rows to fetch do
   5)    fetch row
   6)    repeat
   7)        fetch chunk of long
   8)    until have all of it
   9) done

If your select selects more than one row the need for step 4 may
become a bit clearer... the blob_read always applies to the row
that was last fetched.

Thanks to Jurgen Botz <jbotz@reference.com>

----------------------------------------------------------------------
Example for reading LONG fields via blob_read:
 
	$dbh->{RaiseError} = 1;
	$dbh->{LongTruncOk} = 1; # truncation on initial fetch is ok
	$sth = $dbh->prepare("SELECT key, long_field FROM table_name");
	$sth->execute;
	while ( ($key) = $sth->fetchrow_array) {
		my $offset = 0;
		my $lump = 4096; # use benchmarks to get best value for you
		my @frags;
		while (1) {
			my $frag = $sth->blob_read(1, $offset, $lump);
			last unless defined $frag;
			my $len = length $frag;
			last unless $len;
			push @frags, $frag;
			$offset += $len;
		}
		my $blob = join "", @frags;
		print "$key: $blob\n";
	}

With thanks to james.taylor@srs.gov and desilva@ind70.industry.net.

----------------------------------------------------------------------

Example for inserting LONGS From: Andrew Berry <adb@bha.oz.au>

# Assuming the existence of @row and an associative array (%clauses) containing the 
# column names and placeholders, and an array @types containing column types ...

	$ih = $db->prepare("INSERT INTO $table ($clauses{names})
				 VALUES ($clauses{places})")
			|| die "prepare insert into $table: " . $db->errstr;		  

	$attrib{'ora_type'} = $longrawtype;  # $longrawtype == 24

	##-- bind the parameter for each of the columns
	for ($i = 0; $i < @types; $i++) {

		##-- long raw values must have their type attribute explicitly specified
		if ($types[$i] == $longrawtype) {
			$ih->bind_param($i+1, $row[$i], \%attrib)
				|| die "binding placeholder for LONG RAW " . $db->errstr;
		}
		##-- other values work OK with the default attributes
		else {
			$ih->bind_param($i+1, $row[$i])
				|| die "binding placeholder" . $db->errstr;
		}
	}

	$ih->execute || die "execute INSERT into $table: " . $db->errstr;

----------------------------------------------------------------------
