package CatalystX::GlobalContext;

use strict;
use warnings;
use parent 'Exporter';

use Scalar::Util 'weaken';

use vars '$c';
our @EXPORT_OK = '$c';

=head1 NAME

CatalystX::GlobalContext - Export Catalyst Context

=head1 VERSION

Version 0.019

=cut

our $VERSION = '0.019';

=head1 SYNOPSIS

    package MyApp::Controller::Root;

    use CatalystX::GlobalContext ();

    sub auto {
        my ($self, $c) = @_;
        CatalystX::GlobalContext->set_context($c);        
        1;
    }
    
    package Some::Other::Module;

    use CatalystX::GlobalContext '$c';

    ...
    do stuff with $c
    ...

=head1 DESCRIPTION

This module, in combination with L<Catalyst::Controller::WrapCGI> or
L<Catalyst::Controller::CGIBin> is for helping you run legacy mod_perl code in
L<Catalyst>.

You save a copy of $c somewhere at the beginning of the request cycle, and it is
then accessible through an export where you need it.

You can then rip out C<Apache::> type things, and replace them with things based on
C<$c>.

What we really need is a set of C<Apache::> compatibility classes, but that doesn't
exist yet.

DO NOT USE THIS MODULE IN NEW CODE

=head1 CLASS METHODS

=head2 CatalystX::GlobalContext->set_context($c)

Saves a weakened reference to the Catalyst context,
which is accessible from other modules as an export.

=cut

sub set_context {
    $c = $_[1];
    weaken $c;
}

=head1 SEE ALSO

L<Catalyst::Controller::CGIBin>, L<Catalyst::Controller::WrapCGI>,
L<Catalyst>

=head1 AUTHOR

Rafael Kitover, C<< <rkitover at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalyst-controller-wrapcgi
at rt.cpan.org>, or through the web interface at
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

1; # End of CatalystX::GlobalContext

# vim: expandtab shiftwidth=4 ts=4 tw=80:
