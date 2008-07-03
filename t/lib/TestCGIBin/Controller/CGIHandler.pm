package TestCGIBin::Controller::CGIHandler;

use parent 'Catalyst::Controller::CGIBin';

# try out a forward
sub dongs : Local Args(0) {
    my ($self, $c) = @_;
    $c->forward('/cgihandler/CGI_path_test_pl');
}

# try resolved forward
sub mtfnpy : Local Args(0) {
    my ($self, $c) = @_;
    $c->forward($self->cgi_action('path/test.pl'));
}

1;
