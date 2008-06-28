package TestApp::Controller::Root;

use parent 'Catalyst::Controller::WrapCGI';

__PACKAGE__->config->{namespace} = '';

my $cgi = sub {
    use CGI ':standard';

    print header;
    print 'foo:',param('foo'),' bar:',param('bar')
};

sub handle_cgi : Path('/cgi-bin/test.cgi') {
    my ($self, $c) = @_;
    $self->cgi_to_response($c, $cgi);
}

1;
