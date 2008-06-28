package Catalyst::Plugin::CGIBin;

use strict;
use warnings;

=head1 NAME

Catalyst::Plugin::CGIBin - Server CGIs from root/cgi-bin

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';


=head1 SYNOPSIS

In your .conf:
    <Plugin::CGIBin>
        controller MyApp::Controller::Foo
    </Plugin::CGIBin>

    <MyApp::Controller::Foo>
        <CGI>
            pass_env PERL5LIB
            pass_env PATH
        </CGI>
    </MyApp::Controller::Foo>

=head1 DESCRIPTION

Dispatches to CGI files in root/cgi-bin through the configured controller, which
must inherit from L<Catalyst::Controller::WrapCGI>.

I still need to write the code :)

=cut

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
