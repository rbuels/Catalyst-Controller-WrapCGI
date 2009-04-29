package TestApp::Controller::Root;

use parent 'Catalyst::Controller::WrapCGI';
use CGI ();

__PACKAGE__->config->{namespace} = '';

my $cgi = sub {
    my $cgi = CGI->new;
    print $cgi->header;
    print 'foo:',$cgi->param('foo'),' bar:',$cgi->param('bar');
    if (my $fh = $cgi->param('baz')) {
      local $/;
      print ' baz:',<$fh>;
    }
    if (my $fh = $cgi->param('quux')) {
      local $/;
      print ' quux:',<$fh>;
    }
    die $cgi->cgi_error if $cgi->cgi_error;
};

sub handle_cgi : Path('/cgi-bin/test.cgi') {
    my ($self, $c) = @_;
    $self->cgi_to_response($c, $cgi);
}

sub test_path_info : Path('/cgi-bin/test_pathinfo.cgi') {
    my ($self, $c) = @_;

    $self->cgi_to_response($c, sub {
        my $cgi = CGI->new;
        print $cgi->header;
        print $ENV{PATH_INFO}
    });
}

sub test_filepath_info : Path('/cgi-bin/test_filepathinfo.cgi') {
    my ($self, $c) = @_;

    $self->cgi_to_response($c, sub {
        my $cgi = CGI->new;
        print $cgi->header;
        print $ENV{FILEPATH_INFO}
    });
}

sub test_script_name : Path('/cgi-bin/test_scriptname.cgi') {
    my ($self, $c) = @_;

    $self->cgi_to_response($c, sub {
        my $cgi = CGI->new;
        print $cgi->header;
        print $ENV{SCRIPT_NAME}
    });
}

1;
