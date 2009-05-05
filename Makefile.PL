use inc::Module::Install;

name     'Catalyst-Controller-WrapCGI';
all_from 'lib/Catalyst/Controller/WrapCGI.pm';
author   'Matt S. Trout <mst@shadowcat.co.uk>';

requires 'Catalyst' => '5.80002';
requires 'HTTP::Request::AsCGI' => '0.8';;
requires 'File::Find::Rule';
requires 'List::MoreUtils';
requires 'File::Slurp';
requires 'URI' => '1.37';
requires 'parent';
requires 'namespace::clean';
requires 'Task::Weaken';
requires 'LWP';
requires 'Moose';

test_requires 'Catalyst::Plugin::Static::Simple';
test_requires 'CGI';

build_requires 'Test::More' => '0.86';

auto_install;

WriteAll;
