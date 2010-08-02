#!/usr/bin/perl
use CGI ':standard';
print header;
print "c:$c";
print "global_array:@global_array";
print "global_hash:$global_hash{zip}";
