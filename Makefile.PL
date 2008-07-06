use inc::Module::Install;

name     'Catalyst-Controller-WrapCGI';
all_from 'lib/Catalyst/Controller/WrapCGI.pm';
author   'Matt S. Trout <mst@shadowcat.co.uk>';

requires 'Catalyst' => '5.7007';
requires 'Class::C3';
requires 'parent';
requires 'Task::Weaken';
requires 'HTTP::Request::AsCGI';
requires 'URI';
requires 'File::Find::Rule';
requires 'List::MoreUtils';
requires 'File::Slurp';

build_requires 'Test::More';

auto_install;

WriteAll;
