#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use HTTP::Request::Common;

use Catalyst::Test 'TestCGIBin';

my $response = request POST '/my-bin/path/globals.pl', [
    some => 'chickens',
];

is( $response->content, 'c:', 'globals were not set');

done_testing;
