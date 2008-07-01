package Catalyst::Controller::CGIBin;

use strict;
use warnings;

use Class::C3;
use URI::Escape;
use File::Slurp 'slurp';
use File::Find::Rule ();
use Cwd;
use Catalyst::Exception ();
use File::Spec::Functions 'splitdir';

use parent 'Catalyst::Controller::WrapCGI';

=head1 NAME

Catalyst::Controller::CGIBin - Serve CGIs from root/cgi-bin

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

In your controller:

    package MyApp::Controller::Foo;

    use parent qw/Catalyst::Controller::CGIBin/;

    # example of a forward to /cgi-bin/hlagh/mtfnpy.cgi
    sub dongs : Local Args(0) {
        my ($self, $c) = @_;
        $c->forward($self->cgi_action('hlagh/mtfnpy.cgi'));
    }

In your .conf:

    <Controller::Foo>
        <CGI>
            username_field username # used for REMOTE_USER env var
            pass_env PERL5LIB
            pass_env PATH
            pass_env /^MYAPP_/
        </CGI>
    </Controller::Foo>

=head1 DESCRIPTION

Dispatches to executable CGI files in root/cgi-bin for /cgi-bin/ paths.

A path such as C<root/cgi-bin/hlagh/bar.cgi> will get the private path
C<foo/CGI_hlagh_bar_cgi>, for controller Foo, with the C</>s converted to C<_>s
and prepended with C<CGI_>, as well as all non-word characters converted to
C<_>s. This is because L<Catalyst> action names can't have non-word characters
in them.

Inherits from L<Catalyst::Controller::WrapCGI>, see the documentation for that
module for configuration information.

=cut

sub register_actions {
    my ($self, $c) = @_;

    my $cwd = getcwd;

    my $cgi_bin = $c->path_to('root', 'cgi-bin');

    chdir $cgi_bin ||
        Catalyst::Exception->throw(
            message => 'You have no root/cgi-bin directory'
        );

    my $namespace = $self->action_namespace($c);

    my $class = ref $self || $self;

    for my $file (File::Find::Rule->executable->file->in(".")) {
        my ($cgi, $type);
        my $code = do { no warnings; eval 'sub { '.slurp($file).' }' };

        if (!$@) {
            $cgi = $code;
            $type = 'Perl';
        } else {
            $cgi = sub { system "$cgi_bin/$file" };
            $type = 'Non-Perl';
            undef $@;
        }

        $c->log->info("Registering root/cgi_bin/$file as a $type CGI.")
            if $c->debug;

        my $action_name = $self->cgi_action($file);
        my $path        = join '/' => splitdir($file);
        my $reverse     = $namespace ? "$namespace/$action_name" : $action_name;
        my $attrs       = { Path => [ "cgi-bin/$path" ], Args => [ 0 ] };

        $code = sub {
            my ($controller, $context) = @_;
            $controller->cgi_to_response($context, $cgi)
        };

        my $action = $self->create_action(
            name       => $action_name,
            code       => $code,
            reverse    => $reverse,
            namespace  => $namespace,
            class      => $class,
            attributes => $attrs
        );

        $c->dispatcher->register($c, $action);
    }

    chdir $cwd;

    $self->next::method($c, @_);
}

=head1 METHODS

=head2 $self->cgi_action($cgi_path)

Takes a path to a CGI from C<root/cgi-bin> such as C<foo/bar.cgi> and returns
the action name it is registered as.

=cut

sub cgi_action {
    my ($self, $cgi) = @_;

    my $action_name = 'CGI_' . join '_' => splitdir($cgi);
    $action_name    =~ s/\W/_/g;

    $action_name
}

=head1 AUTHOR

Rafael Kitover, C<< <rkitover at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalyst-controller-wrapcgi at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Controller-WrapCGI>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

More information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Catalyst-Controller-WrapCGI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Catalyst-Controller-WrapCGI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Catalyst-Controller-WrapCGI>

=item * Search CPAN

L<http://search.cpan.org/dist/Catalyst-Controller-WrapCGI>

=back

=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Rafael Kitover

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Catalyst::Controller::CGIBin

# vim: expandtab shiftwidth=4 ts=4 tw=80:
