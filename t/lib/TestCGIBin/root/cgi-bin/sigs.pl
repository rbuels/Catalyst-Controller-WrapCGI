#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

BEGIN { $SIG{USR1} = 'IGNORE'; }

$SIG{USR1} = 'IGNORE';

print header;
