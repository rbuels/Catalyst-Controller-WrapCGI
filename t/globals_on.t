#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use HTTP::Request::Common;

use Catalyst::Test 'TestCGIBinRoot';

my $response = request POST '/cgi/globals.pl';

like( $response->content, qr/c:TestCGIBinRoot=/, 'globals were set');

done_testing;
