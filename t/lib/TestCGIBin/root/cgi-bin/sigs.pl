#!/usr/bin/perl 

use strict;
use warnings;

use CGI ':standard';

$SIG{__DIE__} = sub { print "DIED!\n" };
$SIG{__WARN__} = sub { print "WARNED!\n" };

print header;
