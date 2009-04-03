#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 4;

use Catalyst::Test 'TestCGIBin';
use HTTP::Request::Common;

# this should be ignored
$ENV{MOD_PERL} = "mod_perl/2.0";

my $response = request POST '/cgi-bin/path/test.pl', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to Perl CGI File');

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

SKIP: {
    skip "Can't run shell scripts on non-*nix", 1
        if $^O eq 'MSWin32' || $^O eq 'VMS';

    is(get('/cgi-bin/test.sh'), "Hello!\n", 'Non-Perl CGI File');
}
