#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 4;

use Catalyst::Test 'TestApp';
use HTTP::Request::Common;

my $response = request POST '/cgi-bin/test.cgi', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to CGI');

$response = request '/cgi-bin/test_pathinfo.cgi/path/%2Finfo';
is($response->content, '/path/%2Finfo', 'PATH_INFO is correct');

$response = request '/cgi-bin/test_filepathinfo.cgi/path/%2Finfo';
is($response->content, '/test_filepath_info/path/%2Finfo',
    'FILEPATH_INFO is correct (maybe)');

$response = request '/cgi-bin/test_scriptname.cgi/foo/bar';
is($response->content, '/cgi-bin/test_scriptname.cgi',
    'SCRIPT_NAME is correct');
