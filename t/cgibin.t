#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 8;

use Catalyst::Test 'TestCGIBin';
use HTTP::Request::Common;

# this should be ignored
$ENV{MOD_PERL} = "mod_perl/2.0";

my $response = request POST '/my-bin/path/test.pl', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to Perl CGI File');

$response = request POST '/my-bin/exit.pl', [
    name => 'world',
];

is($response->content, 'hello world', 'POST to Perl CGI with exit()');

$response = request POST '/my-bin/exit.pl', [
    name => 'world',
    exit => 17,
];

is($response->code, 500, 'POST to Perl CGI with nonzero exit()');

$response = request POST '/cgihandler/dongs', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz',
    'POST to Perl CGI File through a forward');

$response = request POST '/cgihandler/mtfnpy', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz',
    'POST to Perl CGI File through a forward via cgi_action');

$response = request '/my-bin/path/testdata.pl';
is($response->content, "testing\n",
    'scripts with __DATA__ sections work');

$response = request '/my-bin/pathinfo.pl/path/info';
is($response->content, '/path/info',
    'PATH_INFO works');

SKIP: {
    skip "Can't run shell scripts on non-*nix", 1
        if $^O eq 'MSWin32' || $^O eq 'VMS';

    is(get('/my-bin/test.sh'), "Hello!\n", 'Non-Perl CGI File');
}
