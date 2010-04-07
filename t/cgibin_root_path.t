#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 1;

use Catalyst::Test 'TestCGIBinRoot';
use HTTP::Request::Common;

# Test configurable path root and dir

my $response = request POST '/cgi/path/test.pl', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to Perl CGI File');
