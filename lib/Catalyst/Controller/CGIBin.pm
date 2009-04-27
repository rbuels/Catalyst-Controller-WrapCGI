package Catalyst::Controller::CGIBin;

use Moose;
use mro 'c3';

extends 'Catalyst::Controller::WrapCGI';

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

=head1 NAME

Catalyst::Controller::CGIBin - Serve CGIs from root/cgi-bin

=head1 VERSION

Version 0.011

=cut

our $VERSION = '0.011';

=head1 SYNOPSIS

In your controller:

    package MyApp::Controller::Foo;

    use parent qw/Catalyst::Controller::CGIBin/;

    # example of a forward to /cgi-bin/hlagh/mtfnpy.cgi
    sub serve_cgi : Local Args(0) {
        my ($self, $c) = @_;
        $c->forward($self->cgi_action('hlagh/mtfnpy.cgi'));
    }

In your .conf:

    <Controller::Foo>
        cgi_root_path cgi-bin
        cgi_dir       cgi-bin
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
for every invocation. This may be supported in the future if there's interest.

CGI paths are converted into action names using L</cgi_action>.

Inherits from L<Catalyst::Controller::WrapCGI>, see the documentation for that
module for other configuration information.

=head1 CONFIG PARAMS

=head2 cgi_root_path

The global URI path prefix for CGIs, defaults to C<cgi-bin>.

=head2 cgi_dir

Path from which to read CGI files. Can be relative to C<$MYAPP_HOME/root> or
absolute.  Defaults to C<$MYAPP_HOME/root/cgi-bin>.

=cut

has cgi_root_path => (is => 'ro', isa => 'Str', default => 'cgi-bin');
has cgi_dir       => (is => 'ro', isa => 'Str', default => 'cgi-bin');

sub register_actions {
    my ($self, $app) = @_;

    my $cgi_bin = File::Spec->file_name_is_absolute($self->cgi_dir) ?
        $self->cgi_dir
        : $app->path_to('root', $self->cgi_dir);

    my $namespace = $self->action_namespace($app);

    my $class = ref $self || $self;

    for my $file (File::Find::Rule->file->in($cgi_bin)) {
        my $cgi_path = abs2rel($file, $cgi_bin);

        next if any { $_ eq '.svn' } splitdir $cgi_path;
        next if $cgi_path =~ /\.swp\z/;

        my $path        = join '/' => splitdir($cgi_path);
        my $action_name = $self->cgi_action($path);
        my $public_path = $self->cgi_path($path);
        my $reverse     = $namespace ? "$namespace/$action_name" : $action_name;
        my $attrs       = { Path => [ $public_path ] };

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

# Tell Static::Simple to ignore cgi_dir
    if ($cgi_bin =~ /^@{[ $app->path_to('root') ]}/) {
        my $rel = File::Spec->abs2rel($cgi_bin, $app->path_to('root'));

        if (!any { $_ eq $rel }
                @{ $app->config->{static}{ignore_dirs}||[] }) {
            push @{ $app->config->{static}{ignore_dirs} }, $rel;
        }
    }
}

=head1 METHODS

=head2 cgi_action

C<<$self->cgi_action($cgi)>>

Takes a path to a CGI from C<root/cgi-bin> such as C<foo/bar.cgi> and returns
the action name it is registered as. See L</DESCRIPTION> for a discussion on how
CGI actions are named.

A path such as C<root/cgi-bin/hlagh/bar.cgi> will get the private path
C<foo/CGI_hlagh__bar_cgi>, for controller Foo, with the C</>s converted to C<__>
and prepended with C<CGI_>, as well as all non-word characters converted to
C<_>s. This is because L<Catalyst> action names can't have non-word characters
in them.

This means that C<foo/bar.cgi> and C<foo__bar.cgi> for example will both map to
the action C<CGI_foo__bar_cgi> so B<DON'T DO THAT>.

=cut

sub cgi_action {
    my ($self, $cgi) = @_;

    my $action_name = 'CGI_' . join '__' => split '/' => $cgi;
    $action_name    =~ s/\W/_/g;

    $action_name
}

=head2 cgi_path

C<<$self->cgi_path($cgi)>>

Takes a path to a CGI from C<root/cgi-bin> such as C<foo/bar.cgi> and returns
the public path it should be registered under.

The default is to prefix with C<$cgi_root_path/>, using the C<cgi_root_path>
config setting, above.

=cut

sub cgi_path {
    my ($self, $cgi) = @_;

    my $root = $self->cgi_root_path;
    $root =~ s{/*$}{};
    return "$root/$cgi";
}

=head2 is_perl_cgi

C<<$self->is_perl_cgi($path)>>

Tries to figure out whether the CGI is Perl or not.

If it's Perl, it will be inlined into a sub instead of being forked off, see
L</wrap_perl_cgi>.

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

=head2 wrap_perl_cgi

C<<$self->wrap_perl_cgi($path, $action_name)>>

Takes the path to a Perl CGI and returns a coderef suitable for passing to
cgi_to_response (from L<Catalyst::Controller::WrapCGI>.)

C<$action_name> is the generated name for the action representing the CGI file
from C<cgi_action>.

This is similar to how L<ModPerl::Registry> works, but will only work for
well-written CGIs. Otherwise, you may have to override this method to do
something more involved (see L<ModPerl::PerlRun>.)

Scripts with C<__DATA__> sections now work too, as well as scripts that call
C<exit()>.

=cut

sub wrap_perl_cgi {
    my ($self, $cgi, $action_name) = @_;

    my $code = slurp $cgi;

    $code =~ s/^__DATA__(?:\r?\n|\r\n?)(.*)//ms;
    my $data = $1;

    my $coderef = do {
        no warnings;
        # catch exit() and turn it into (effectively) a return
        # we *must* eval STRING because the code needs to be compiled with the
        # overridden CORE::GLOBAL::exit in view
        #
        # set $0 to the name of the cgi file in case it's used there
        eval ' 
            my $cgi_exited = "EXIT\n";
            BEGIN { *CORE::GLOBAL::exit = sub (;$) {
                die [ $cgi_exited, $_[0] || 0 ];
            } }
            package Catalyst::Controller::CGIBin::_CGIs_::'.$action_name.';
            sub {'
                . 'local *DATA;'
                . q{open DATA, '<', \$data;}
                . qq{local \$0 = "\Q$cgi\E";}
                . q/my $rv = eval {/
                . $code
                . q/};/
                . q{
                    return $rv unless $@;
                    die $@ if $@ and not (
                      ref($@) eq 'ARRAY' and
                      $@->[0] eq $cgi_exited
                    );
                    die "exited nonzero: $@->[1]" if $@->[1] != 0;
                    return $rv;
                }
         . '}';
    };

    croak __PACKAGE__ . ": Could not compile $cgi to coderef: $@" if $@;

    $coderef
}

=head2 wrap_nonperl_cgi

C<<$self->wrap_nonperl_cgi($path, $action_name)>>

Takes the path to a non-Perl CGI and returns a coderef for executing it.

C<$action_name> is the generated name for the action representing the CGI file.

By default returns:

    sub { system $path }

=cut

sub wrap_nonperl_cgi {
    my ($self, $cgi, $action_name) = @_;

    sub { system $cgi }
}

__PACKAGE__->meta->make_immutable;

=head1 SEE ALSO

L<Catalyst::Controller::WrapCGI>, L<CatalystX::GlobalContext>,
L<Catalyst::Controller>, L<CGI>, L<Catalyst>

=head1 AUTHORS

Rafael Kitover, C<< <rkitover at cpan.org> >>

Hans Dieter Pearcey, C<< <hdp at cpan.org> >>

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
