package Catalyst::Plugin::CGIBin;

use strict;
use warnings;

use Class::C3;
use URI::Escape;
use File::Slurp 'slurp';
use File::Find::Rule ();
use Cwd;
use Catalyst::Exception ();

=head1 NAME

Catalyst::Plugin::CGIBin - Serve CGIs from root/cgi-bin

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

In MyApp.pm:

    use Catalyst;

    __PACKAGE__->setup(qw/CGIBin/);

In your .conf:

    <Plugin::CGIBin>
        controller Foo
    </Plugin::CGIBin>

    <Controller::Foo>
        <CGI>
            pass_env PERL5LIB
            pass_env PATH
        </CGI>
    </Controller::Foo>

=head1 DESCRIPTION

Dispatches to executable CGI files in root/cgi-bin through the configured
controller, which must inherit from L<Catalyst::Controller::WrapCGI>.

=cut

my ($cgi_controller, $cgis);

sub setup {
    my $app = shift;

    my $cwd = getcwd;

    my $cgi_bin = $app->path_to('root', 'cgi-bin');

    chdir $cgi_bin ||
        Catalyst::Exception->throw(
            message => 'You have no root/cgi-bin directory'
        );

    $cgi_controller = $app->config->{'Plugin::CGIBin'}{controller} ||
        Catalyst::Exception->throw(
            message => 'You must configure a controller for Plugin::CGIBin'
        );

    for my $cgi (File::Find::Rule->executable->file->in(".")) {
        my $code = do { no warnings; eval 'sub { '.slurp($cgi).' }' };
        if (!$@) { # Perl source
            $cgis->{$cgi} = $code;
            undef $@;
        } else { # some other type of executable
            $cgis->{$cgi} = sub { system "$cgi_bin/$cgi" };
        }
    }

    chdir $cwd;

    $app->next::method(@_);
}

sub dispatch {
    my $c = shift;
    my $path = uri_unescape($c->req->path);

    if ($path =~ m!^cgi-bin/(.*)!) {
        my $cgi = $cgis->{$1};

        if ($cgi) {
            $c->controller($cgi_controller)->cgi_to_response(
                $c, $cgi
            );
            return;
        }
    }

    $c->next::method(@_);
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

1; # End of Catalyst::Plugin::CGIBin

# vim: expandtab shiftwidth=4 ts=4 tw=80:
