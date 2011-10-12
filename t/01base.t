#!perl -w

# Base DBD Driver Test
use Test::More tests => 6;

require_ok('DBI');

eval {
    import DBI;
};
ok(!$@, 'import DBI');

$switch = DBI->internal;
is(ref $switch, 'DBI::dr', 'internal');

eval {
    # This is a special case. install_driver should not normally be used.
    $drh = DBI->install_driver('Oracle');
};
my $ev = $@;
ok(!$ev, 'install_driver');
if ($ev) {
    $ev =~ s/\n\n+/\n/g;
    warn "Failed to load Oracle extension and/or shared libraries:\n$@";
    warn "The remaining tests will probably also fail with the same error.\a\n\n";
    # try to provide some useful pointers for some cases
    if ($@ =~ /Solaris patch.*Java/i) {
	warn "*** Please read the README.java.txt file for help. ***\n";
    }
    else {
	warn "*** Please read the README and README.help.txt files for help. ***\n";
    }
    warn "\n";
    sleep 5;

}

SKIP: {
    skip 'install_driver failed - skipping remaining', 2 if $ev;

    is(ref $drh, 'DBI::dr', 'install_driver');

    ok($drh->{Version}, 'version');
}

# end.

__END__

You must install a Solaris patch to run this version of
the Java runtime.
Please see the README and release notes for more information.
