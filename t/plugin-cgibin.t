#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More tests => 2;

use Catalyst::Test 'TestPlugin';
use HTTP::Request::Common;

my $response = request POST '/cgi-bin/test.pl', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to Perl CGI File');

is(get('/cgi-bin/test.sh'), "Hello!\n", 'Non-Perl CGI File');
