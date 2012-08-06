#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Capsulary::Tools' ) || print "Bail out!
";
}

diag( "Testing Capsulary::Tools $Capsulary::Tools::VERSION, Perl $], $^X" );
