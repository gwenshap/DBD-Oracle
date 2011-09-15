use strict;
use warnings;

use ExtUtils::Manifest qw/ fullcheck /;

use Test::More tests => 1;

my ( $missing, $extra ) = do {
    local *STDERR;

    # hush little baby, don't you cry
    open STDERR, '>', \my $stderr;

    fullcheck();
};

ok @$missing + @$extra == 0, 'manifest in sync' or do {
    diag "missing files:\n", map { " \t $_\n " } @$missing if @$missing;
    diag "extra files: \n",  map { "\t$_\n" } @$extra      if @$extra;
};

