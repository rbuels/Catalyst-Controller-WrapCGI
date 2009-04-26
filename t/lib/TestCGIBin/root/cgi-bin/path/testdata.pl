#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

print header;
print do { local $/; <DATA> };

__DATA__
testing
