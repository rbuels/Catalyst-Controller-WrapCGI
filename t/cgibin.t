#!perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use HTTP::Request::Common;

my %orig_sig;
BEGIN {
    %orig_sig = %SIG;
# perl < 5.8.9 won't set a %SIG entry to undef, it sets it to ''
    %orig_sig = map { defined $_ ? $_ : '' } %orig_sig
        if $] < 5.008009;
}

use Catalyst::Test 'TestCGIBin';

# this should be ignored
$ENV{MOD_PERL} = "mod_perl/2.0";

is_deeply \%SIG, \%orig_sig, '%SIG is preserved on compile';

my $response = request POST '/my-bin/path/test.pl', [
    foo => 'bar',
    bar => 'baz'
];

is($response->content, 'foo:bar bar:baz', 'POST to Perl CGI File');

$response = request '/my-bin/path/test.pl?foo=bar&bar=baz';

is($response->content, 'foo:bar bar:baz',
    'Perl CGI File invoked with query params');

$response = request POST '/my-bin/exit.pl', [
    name => 'world',
];

is($response->content, 'hello world', 'POST to Perl CGI with exit()');

$response = request POST '/my-bin/exit.pl', [
    name => 'world',
    exit => 17,
];

is($response->code, 500, 'POST to Perl CGI with nonzero exit()');

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

ok request '/my-bin/sigs.pl';

is_deeply \%SIG, \%orig_sig, '%SIG is preserved';

SKIP: {
    skip "Can't run shell scripts on non-*nix", 1
        if $^O eq 'MSWin32' || $^O eq 'VMS';

# for some reason the +x is not preserved in the dist
    system "chmod +x $Bin/lib/TestCGIBin/root/cgi-bin/test.sh";
    system "chmod +x $Bin/lib/TestCGIBin/root/cgi-bin/exit_nonzero.sh";

    is(get('/my-bin/test.sh'), "Hello!\n", 'Non-Perl CGI File');

    $response = request GET '/my-bin/exit_nonzero.sh';
    is $response->code, 500, 'Non-Perl CGI with non-zero exit dies';
}

done_testing;
