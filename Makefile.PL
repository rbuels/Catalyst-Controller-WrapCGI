use inc::Module::Install 0.91;

require Module::Install::ReadmeFromPod;

name     'Catalyst-Controller-WrapCGI';
all_from 'lib/Catalyst/Controller/WrapCGI.pm';
author   'Matt S. Trout <mst@shadowcat.co.uk>';

requires 'Catalyst' => '5.80015';
requires 'HTTP::Request::AsCGI' => '1.2';
requires 'CGI::Compile' => '0.07';
requires 'File::pushd';
requires 'File::Find::Rule';
requires 'List::MoreUtils';
requires 'URI' => '1.37';
requires 'parent';
requires 'namespace::clean';
requires 'Task::Weaken';
requires 'LWP';
requires 'Moose';

test_requires 'Test::More' => '0.92';
test_requires 'Catalyst::Plugin::Static::Simple';
test_requires 'CGI';

readme_from 'lib/Catalyst/Controller/CGIBin.pm';

realclean_files qw/README MANIFEST/;

auto_provides;
auto_install;
resources repository => 'git://git.shadowcat.co.uk/catagits/Catalyst-Controller-WrapCGI.git';
WriteAll;
