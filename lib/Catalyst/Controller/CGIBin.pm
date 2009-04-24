package Catalyst::Controller::CGIBin;

use strict;
use warnings;

use MRO::Compat;
use mro 'c3';
use File::Slurp 'slurp';
use File::Find::Rule ();
use Catalyst::Exception ();
use File::Spec::Functions qw/splitdir abs2rel/;
use IPC::Open3;
use Symbol 'gensym';
use List::MoreUtils 'any';
use IO::File ();
use Carp;
use namespace::clean -except => 'meta';

use parent 'Catalyst::Controller::WrapCGI';

=head1 NAME

Catalyst::Controller::CGIBin - Serve CGIs from root/cgi-bin

=head1 VERSION

Version 0.006

=cut

our $VERSION = '0.006';

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

Dispatches to CGI files in root/cgi-bin for /cgi-bin/ paths.

Unlike L<ModPerl::Registry> this module does _NOT_ stat and recompile the CGI
for every invocation. If this is something you need, let me know.

CGI paths are converted into action names using cgi_action (below.)

A path such as C<root/cgi-bin/hlagh/bar.cgi> will get the private path
C<foo/CGI_hlagh_bar_cgi>, for controller Foo, with the C</>s converted to C<_>s
and prepended with C<CGI_>, as well as all non-word characters converted to
C<_>s. This is because L<Catalyst> action names can't have non-word characters
in them.

Inherits from L<Catalyst::Controller::WrapCGI>, see the documentation for that
module for configuration information.

=cut

sub register_actions {
    my ($self, $app) = @_;

    my $cgi_bin = $app->path_to('root', 'cgi-bin');

    my $namespace = $self->action_namespace($app);

    my $class = ref $self || $self;

    for my $file (File::Find::Rule->file->in($cgi_bin)) {
        my $cgi_path = abs2rel($file, $cgi_bin);

        next if any { $_ eq '.svn' } splitdir $cgi_path;

        my $path        = join '/' => splitdir($cgi_path);
        my $action_name = $self->cgi_action($path);
        my $reverse     = $namespace ? "$namespace/$action_name" : $action_name;
        my $attrs       = { Path => [ "cgi-bin/$path" ], Args => [ 0 ] };

        my ($cgi, $type);

        if ($self->is_perl_cgi($file)) { # syntax check passed
            $type = 'Perl';
            $cgi  = $self->wrap_perl_cgi($file, $action_name);
        } else {
            $type = 'Non-Perl';
            $cgi  = $self->wrap_nonperl_cgi($file, $action_name);
        }

        $app->log->info("Registering root/cgi-bin/$cgi_path as a $type CGI.")
            if $app->debug;

        my $code = sub {
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

        $app->dispatcher->register($app, $action);
    }

    $self->next::method($app, @_);

# Tell Static::Simple to ignore the cgi-bin dir.
    if (!any{ $_ eq 'cgi-bin' } @{ $app->config->{static}{ignore_dirs}||[] }) {
        push @{ $app->config->{static}{ignore_dirs} }, 'cgi-bin';
    }
}

=head1 METHODS

=head2 $self->cgi_action($cgi_path)

Takes a path to a CGI from C<root/cgi-bin> such as C<foo/bar.cgi> and returns
the action name it is registered as. See L</DESCRIPTION> for a discussion on how
CGI actions are named.

=cut

sub cgi_action {
    my ($self, $cgi) = @_;

    my $action_name = 'CGI_' . join '_' => split '/' => $cgi;
    $action_name    =~ s/\W/_/g;

    $action_name
}

=head2 $self->is_perl_cgi($path)

Tries to figure out whether the CGI is Perl or not.

If it's Perl, it will be inlined into a sub instead of being forked off, see
wrap_perl_cgi (below.)

If it's not doing what you expect, you might want to override it, and let me
know as well!

=cut

sub is_perl_cgi {
    my ($self, $cgi) = @_;

    my $shebang = IO::File->new($cgi)->getline;

    return 0 if $shebang !~ /perl/ && $cgi !~ /\.pl\z/;

    my $taint_check = $shebang =~ /-T/ ?  '-T' : '';

    open NULL, '>', File::Spec->devnull;
    my $pid = open3(gensym, '&>NULL', '&>NULL', "$^X $taint_check -c $cgi");
    close NULL;
    waitpid $pid, 0;

    $? >> 8 == 0
}

=head2 $self->wrap_perl_cgi($path, $action_name)

Takes the path to a Perl CGI and returns a coderef suitable for passing to
cgi_to_response (from L<Catalyst::Controller::WrapCGI>.)

C<$action_name> is the generated name for the action representing the CGI file.

This is similar to how L<ModPerl::Registry> works, but will only work for
well-written CGIs. Otherwise, you may have to override this method to do
something more involved (see L<ModPerl::PerlRun>.)

=cut

sub wrap_perl_cgi {
    my ($self, $cgi, $action_name) = @_;

    my $code = slurp $cgi;

    $code =~ s/^__DATA__\r?\n(.*)//ms;
    my $data = $1;

    my $coderef = do {
        no warnings;
        eval ' 
            package Catalyst::Controller::CGIBin::_CGIs_::'.$action_name.';
            sub {'
                . 'local *DATA;'
                . q{open DATA, '<', \$data;}
                . $code
         . '}';
    };

    croak __PACKAGE__ . ": Could not compile $cgi to coderef: $@" if $@;

    $coderef
}

=head2 $self->wrap_nonperl_cgi($path, $action_name)

Takes the path to a non-Perl CGI and returns a coderef for executing it.

C<$action_name> is the generated name for the action representing the CGI file.

By default returns:

    sub { system $path }

=cut

sub wrap_nonperl_cgi {
    my ($self, $cgi, $action_name) = @_;

    sub { system $cgi }
}

=head1 SEE ALSO

L<Catalyst::Controller::WrapCGI>, L<CatalystX::GlobalContext>,
L<Catalyst::Controller>, L<CGI>, L<Catalyst>

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
