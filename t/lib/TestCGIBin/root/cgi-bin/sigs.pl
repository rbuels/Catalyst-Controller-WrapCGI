#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

$SIG{USR1} = 'IGNORE';

print header;
