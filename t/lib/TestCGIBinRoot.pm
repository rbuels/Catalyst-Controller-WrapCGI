package TestCGIBinRoot;

use Catalyst::Runtime '5.70';
use parent 'Catalyst';

__PACKAGE__->config({
    Controller::CGIHandler => {
        cgi_root_path => 'cgi',
        cgi_dir => 'cgi',
        cgi_globals => {
            '$c' => 'CONTEXT',
            '%global_hash' => { zip => 'zee' },
            '@global_array' => [qw[ noggin quux ]],
        },
    }
});

__PACKAGE__->setup(qw/Static::Simple/);

1;
