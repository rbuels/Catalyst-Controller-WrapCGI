use inc::Module::Install;

name     'Catalyst-Controller-WrapCGI';
all_from 'lib/Catalyst/Controller/WrapCGI.pm';
author   'Matt S. Trout <mst@shadowcat.co.uk>';

requires 'Catalyst' => '5.80002';
requires 'HTTP::Request::AsCGI' => '0.8';;
requires 'File::Find::Rule';
requires 'List::MoreUtils';
requires 'File::Slurp';

test_requires 'Catalyst::Plugin::Static::Simple';

build_requires 'Test::More' => '0.86';

auto_install;

WriteAll;
