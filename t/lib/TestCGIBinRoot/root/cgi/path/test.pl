#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

die '$ENV{MOD_PERL} must not be set' if $ENV{MOD_PERL};

print header;
print 'foo:',param('foo'),' bar:',param('bar')
