package TestApp::Controller::Root;

use parent 'Catalyst::Controller::WrapCGI';
use CGI ();

__PACKAGE__->config->{namespace} = '';

my $cgi = sub {
    my $cgi = CGI->new;
    print $cgi->header;
    print 'foo:',$cgi->param('foo'),' bar:',$cgi->param('bar')
};

sub handle_cgi : Path('/cgi-bin/test.cgi') {
    my ($self, $c) = @_;
    $self->cgi_to_response($c, $cgi);
}

1;
