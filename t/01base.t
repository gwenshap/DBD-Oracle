#!perl -w

# Base DBD Driver Test

print "1..$tests\n";

require DBI;
print "ok 1\n";

import DBI;
print "ok 2\n";

$switch = DBI->internal;
(ref $switch eq 'DBI::dr') ? print "ok 3\n" : print "not ok 3\n";

eval {

# This is a special case. install_driver should not normally be used.
$drh = DBI->install_driver('Oracle');
(ref $drh eq 'DBI::dr') ? print "ok 4\n" : print "not ok 4\n";

};
if ($@) {
	$@ =~ s/\n\n+/\n/g if $@;
    warn "Failed to load Oracle extension and/or shared libraries:\n$@" if $@;
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

print "ok 5\n" if $drh->{Version};

BEGIN { $tests = 5 }
exit 0;
# end.

__END__

You must install a Solaris patch to run this version of
the Java runtime.
Please see the README and release notes for more information.
