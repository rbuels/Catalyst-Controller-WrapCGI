#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

print header;
print 'foo:',param('foo'),' bar:',param('bar')
