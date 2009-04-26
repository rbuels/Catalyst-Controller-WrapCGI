#!/usr/bin/perl

use strict;
use warnings;

use CGI ':standard';

print header;
print "hello " . param('name');
exit(param('exit') || 0);
