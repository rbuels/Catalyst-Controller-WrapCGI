#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

print header;
print $ENV{PATH_INFO};
