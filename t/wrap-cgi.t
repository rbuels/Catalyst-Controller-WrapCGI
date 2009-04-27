#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 2;

use Catalyst::Test 'TestApp';
use HTTP::Request::Common;

my $response = request POST '/cgi-bin/test.cgi', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to CGI');

$response = request '/cgi-bin/test_pathinfo.cgi/path/info';

is($response->content, '/path/info', 'PATH_INFO is correct');
