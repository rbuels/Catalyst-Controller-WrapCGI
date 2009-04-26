use inc::Module::Install;

name     'Catalyst-Controller-WrapCGI';
all_from 'lib/Catalyst/Controller/WrapCGI.pm';
author   'Matt S. Trout <mst@shadowcat.co.uk>';
include  'Module::AutoInstall';

requires 'Catalyst' => '5.7007';
requires 'parent';
requires 'Task::Weaken';
requires 'HTTP::Request::AsCGI';
requires 'URI';
requires 'File::Find::Rule';
requires 'List::MoreUtils';
requires 'File::Slurp';
requires 'namespace::clean';

requires 'Moose';

if($] < 5.009_005) {
    requires 'Class::C3::XS' => '0.08';
    requires 'Class::C3' => '0.20';
}

test_requires 'Catalyst::Plugin::Static::Simple';

build_requires 'Test::More' => '0.86';

auto_install;

WriteAll;
