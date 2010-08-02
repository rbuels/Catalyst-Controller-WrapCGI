#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use Catalyst::Test 'TestCGIBinRoot';

my $response = get '/cgi/globals.pl';

like( $response, qr/c:TestCGIBinRoot=/, 'globals were set');

$response = get '/cgi/globals.pl';
like( $response, qr/c:TestCGIBinRoot=/, 'globals were set');
like( $response, qr/global_array:noggin quux/, 'globals were set 2');
like( $response, qr/global_hash:zee/, 'globals were set 3');

done_testing;
