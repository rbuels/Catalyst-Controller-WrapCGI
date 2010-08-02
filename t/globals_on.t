#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

use Catalyst::Test 'TestCGIBinRoot';

my $response = get '/cgi/globals.pl';

like( $response, qr/c:TestCGIBinRoot=/, 'globals were set');

done_testing;
