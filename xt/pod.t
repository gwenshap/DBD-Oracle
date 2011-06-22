use Test::More;

eval "use Test::Pod";

plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

pod_file_ok( 'Oracle.pm' );
pod_file_ok( 'lib/DBD/Oracle/Object.pm' );
pod_file_ok( 'lib/DBD/Oracle/GetInfo.pm' );

done_testing;
