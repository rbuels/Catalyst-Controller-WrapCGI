#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 6;

use Catalyst::Test 'TestApp';
use HTTP::Request::Common;

my $response = request POST '/cgi-bin/test.cgi', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to CGI');

$response = request POST '/cgi-bin/test.cgi', [
  foo => 'bar',
  bar => 'baz',
], 'Content-Type' => 'form-data';

is($response->content, 'foo:bar bar:baz', 'POST to CGI (form-data)');

$response = request POST '/cgi-bin/test.cgi',
  Content => [
    foo => 1,
    bar => 2,
    baz => [
        undef,
        'baz',
        'Some-Header' => 'blah',
        'Content-Type' => 'text/plain',
        Content => 3
    ],
    quux => [ undef, quux => Content => 4 ],
  ],
  'Content-Type' => 'form-data';

is($response->content, 'foo:1 bar:2 baz:3 quux:4', 'POST with file upload');

$response = request '/cgi-bin/test_pathinfo.cgi/path/%2Finfo';
is($response->content, '/path/%2Finfo', 'PATH_INFO is correct');

$response = request '/cgi-bin/test_filepathinfo.cgi/path/%2Finfo';
is($response->content, '/test_filepath_info/path/%2Finfo',
    'FILEPATH_INFO is correct (maybe)');

$response = request '/cgi-bin/mtfnpy/test_scriptname.cgi/foo/bar';
is($response->content, '/cgi-bin/mtfnpy/test_scriptname.cgi',
    'SCRIPT_NAME is correct');
