package TestPlugin;

use Catalyst;

__PACKAGE__->config->{'Plugin::CGIBin'} = {
    controller => 'CGIHandler'
};

__PACKAGE__->setup(qw/CGIBin/);

1;
