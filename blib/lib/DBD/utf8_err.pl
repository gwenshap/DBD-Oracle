#!/usr/local/bin/perl
#
# Name:
#	last.pl.

use strict;
use warnings;

use DBI;

# ------
use vars qw($dbh $sth $sql );

   $dbh = DBI->connect('dbi:Oracle:','hr@localhost/XE','hr',{ RaiseError => 1 , PrintError =>0});
    
    
use Encode qw(decode);

my $sth = $dbh->prepare("select ? from dual") || die $dbh->errstr;

my $non_utf8 = "X";
$sth->execute($non_utf8) || die $sth->errstr;

my $utf8 = decode('utf8', $non_utf8);
$sth->execute($utf8) || die $sth->errstr; # DIES

