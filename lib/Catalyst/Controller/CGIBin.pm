package Catalyst::Controller::CGIBin;

use Moose;
use mro 'c3';

extends 'Catalyst::Controller::WrapCGI';

use File::Find::Rule ();
use Catalyst::Exception ();
use File::Spec::Functions qw/splitdir abs2rel/;
use IPC::Open3;
use Symbol 'gensym';
use List::MoreUtils 'any';
use IO::File ();
use File::Temp 'tempfile';
use File::pushd;
use CGI::Compile;
 
use namespace::clean -except => 'meta';

=head1 NAME

Catalyst::Controller::CGIBin - Serve CGIs from root/cgi-bin

=head1 VERSION

Version 0.026

=cut

our $VERSION = '0.026';

=head1 SYNOPSIS

In your controller:

    package MyApp::Controller::Foo;

    use parent qw/Catalyst::Controller::CGIBin/;

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

C<< $self->cgi_action($cgi) >>

Takes a path to a CGI from C<root/cgi-bin> such as C<foo/bar.cgi> and returns
the action name it is registered as.

=cut

sub cgi_action {
    my ($self, $cgi) = @_;

    my $action_name = 'CGI_' . $cgi;
    $action_name =~ s/([^A-Za-z0-9_])/sprintf("_%2x", unpack("C", $1))/eg;

    return $action_name;
}

=head2 cgi_path

C<< $self->cgi_path($cgi) >>

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

C<< $self->is_perl_cgi($path) >>

Tries to figure out whether the CGI is Perl or not.

If it's Perl, it will be inlined into a sub instead of being forked off, see
L</wrap_perl_cgi>.

=cut

sub is_perl_cgi {
    my ($self, $cgi) = @_;

    my (undef, $tempfile) = tempfile;

    my $pid = fork;
    die "Cannot fork: $!" unless defined $pid;

    if ($pid) {
        waitpid $pid, 0;
        my $errors = IO::File->new($tempfile)->getline;
        unlink $tempfile;
        return $errors ? 0 : 1;
    }

    # child
    local *NULL;
    open NULL, '>', File::Spec->devnull;
    open STDOUT, '>&', \*NULL;
    open STDERR, '>&', \*NULL;
    close STDIN;

    eval { $self->wrap_perl_cgi($cgi, '__DUMMY__') };

    IO::File->new(">$tempfile")->print($@);

    exit;
}

=head2 wrap_perl_cgi

C<< $self->wrap_perl_cgi($path, $action_name) >>

Takes the path to a Perl CGI and returns a coderef suitable for passing to
cgi_to_response (from L<Catalyst::Controller::WrapCGI>) using L<CGI::Compile>.

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

    return CGI::Compile->compile($cgi,
        "Catalyst::Controller::CGIBin::_CGIs_::$action_name");
}

=head2 wrap_nonperl_cgi

C<< $self->wrap_nonperl_cgi($path, $action_name) >>

Takes the path to a non-Perl CGI and returns a coderef for executing it.

C<$action_name> is the generated name for the action representing the CGI file.

By default returns something like:

    sub { system $path }

=cut

sub wrap_nonperl_cgi {
    my ($self, $cgi, $action_name) = @_;

    return sub {
        system $cgi;

        if ($? == -1) {
            die "failed to execute CGI '$cgi': $!";
        }
        elsif ($? & 127) {
            die sprintf "CGI '$cgi' died with signal %d, %s coredump",
                ($? & 127),  ($? & 128) ? 'with' : 'without';
        }
        else {
            my $exit_code = $? >> 8;

            return 0 if $exit_code == 0;

            die "CGI '$cgi' exited non-zero with: $exit_code";
        }
    };
}

__PACKAGE__->meta->make_immutable;

=head1 SEE ALSO

L<Catalyst::Controller::WrapCGI>, L<CatalystX::GlobalContext>,
L<Catalyst::Controller>, L<CGI>, L<CGI::Compile>, L<Catalyst>

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

=head1 AUTHOR

See L<Catalyst::Controller::WrapCGI/AUTHOR> and
L<Catalyst::Controller::WrapCGI/CONTRIBUTORS>.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2008-2009 L<Catalyst::Controller::WrapCGI/AUTHOR> and
L<Catalyst::Controller::WrapCGI/CONTRIBUTORS>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Catalyst::Controller::CGIBin

# vim: expandtab shiftwidth=4 ts=4 tw=80:
