package Catalyst::Controller::WrapCGI;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use HTTP::Request::AsCGI;
use HTTP::Request;
use URI;
use Catalyst::Exception ();

=head1 NAME

Catalyst::Controller::WrapCGI - Run CGIs in Catalyst

=head1 VERSION

Version 0.0027

=cut

our $VERSION = '0.0027';

=head1 SYNOPSIS

    package MyApp::Controller::Foo;

    use parent qw/Catalyst::Controller::WrapCGI/;
    use CGI ();

    sub hello : Path('cgi-bin/hello.cgi') {
        my ($self, $c) = @_;

        $self->cgi_to_response($c, sub {
            my $q = CGI->new;
            print $q->header, $q->start_html('Hello'),
                $q->h1('Catalyst Rocks!'),
                $q->end_html;
        });
    }

In your .conf, configure which environment variables to pass:

    <Controller::Foo>
        <CGI>
            username_field username # used for REMOTE_USER env var
            pass_env PERL5LIB
            pass_env PATH
            pass_env /^MYAPP_/
            kill_env MOD_PERL
        </CGI>
    </Controller::Foo>

=head1 DESCRIPTION

Allows you to run Perl code in a CGI environment derived from your L<Catalyst>
context.

B<*WARNING*>: do not export L<CGI> functions into a Controller, it will break
with L<Catalyst> 5.8 onward.

If you just want to run CGIs from files, see L<Catalyst::Controller::CGIBin>.

=head1 CONFIGURATION

C<< $your_controller->{CGI}{pass_env} >> should be an array of environment variables
or regular expressions to pass through to your CGIs. Entries surrounded by C</>
characters are considered regular expressions.

C<< $your_controller->{CGI}{kill_env} >> should be an array of environment
variables or regular expressions to remove from the environment before passing
it to your CGIs.  Entries surrounded by C</> characters are considered regular
expressions.

Default is to pass the whole of C<%ENV>, except for C<MOD_PERL> (that is, the
default C<kill_env> is C<[ 'MOD_PERL' ]>.

C<< $your_controller->{CGI}{username_field} >> should be the field for your user's name, which will be
read from C<< $c->user->obj >>. Defaults to 'username'.

See L</SYNOPSIS> for an example.

=cut

# Hack-around because Catalyst::Engine::HTTP goes and changes
# them to be the remote socket, and FCGI.pm does even dumber things.

open my $REAL_STDIN, "<&=".fileno(*STDIN);
open my $REAL_STDOUT, ">>&=".fileno(*STDOUT);

=head1 METHODS

=head2 $self->cgi_to_response($c, $coderef)

Does the magic of running $coderef in a CGI environment, and populating the
appropriate parts of your Catalyst context with the results.

Calls wrap_cgi (below.)

=cut

sub cgi_to_response {
  my ($self, $c, $script) = @_;
  my $res = $self->wrap_cgi($c, $script);

  # if the CGI doesn't set the response code but sets location they were
  # probably trying to redirect so set 302 for them

  my $location = $res->headers->header('Location');

  if (defined $location && length $location && $res->code == 200) {
    $c->res->status(302);
  } else { 
    $c->res->status($res->code);
  }
  $c->res->body($res->content);
  $c->res->headers($res->headers);
}

=head2 $self->wrap_cgi($c, $coderef)

Runs $coderef in a CGI environment using L<HTTP::Request::AsCGI>, returns an
L<HTTP::Response>.

The CGI environment is set up based on $c.

The environment variables to pass on are taken from the configuration for your
Controller, see L</SYNOPSIS> for an example. If you don't supply a list of
environment variables to pass, the whole of %ENV is used.

Used by cgi_to_response (above), which is probably what you want to use as well.

=cut

sub _filtered_env {
  my ($self, $env) = @_;
  my @ok;

  my $pass_env = $self->{CGI}{pass_env};
  $pass_env = []            if not defined $pass_env;
  $pass_env = [ $pass_env ] unless ref $pass_env;

  my $kill_env = $self->{CGI}{kill_env};
  $kill_env = [ 'MOD_PERL' ] unless defined $kill_env;
  $kill_env = [ $kill_env ]  unless ref $kill_env;

  if (@$pass_env) {
    for (@$pass_env) {
      if (m!^/(.*)/\z!) {
        my $re = qr/$1/;
        push @ok, grep /$re/, keys %$env;
      } else {
        push @ok, $_;
      }
    }
  } else {
    @ok = keys %$env;
  }

  for my $k (@$kill_env) {
    if ($k =~ m!^/(.*)/\z!) {
      my $re = qr/$1/;
      @ok = grep { ! /$re/ } @ok;
    } else {
      @ok = grep { $_ ne $k } @ok;
    }
  }
  return { map {; $_ => $env->{$_} } @ok };
}

sub wrap_cgi {
  my ($self, $c, $call) = @_;
  my $req = HTTP::Request->new(
    map { $c->req->$_ } qw/method uri headers/
  );
  my $body = $c->req->body;
  my $body_content = '';

  $req->content_type($c->req->content_type); # set this now so we can override

  if ($body) { # Slurp from body filehandle
    local $/; $body_content = <$body>;
  } else {
    my $body_params = $c->req->body_parameters;
    if (%$body_params) {
      my $encoder = URI->new;
      $encoder->query_form(%$body_params);
      $body_content = $encoder->query;
      $req->content_type('application/x-www-form-urlencoded');
    }
  }

  my $filtered_env = $self->_filtered_env(\%ENV);

  $req->content($body_content);
  $req->content_length(length($body_content));

  my $username_field = $self->{CGI}{username_field} || 'username';

  my $username = (($c->can('user_exists') && $c->user_exists)
               ? eval { $c->user->obj->$username_field }
                : '');
  my $env = HTTP::Request::AsCGI->new(
              $req,
              ($username ? (REMOTE_USER => $username) : ()),
              %$filtered_env,
            );

  {
    local *STDIN = $REAL_STDIN;   # restore the real ones so the filenos
    local *STDOUT = $REAL_STDOUT; # are 0 and 1 for the env setup

    my $old = select($REAL_STDOUT); # in case somebody just calls 'print'

    my $saved_error;

    $env->setup;
    eval { $call->() };
    $saved_error = $@;
    $env->restore;

    select($old);

    Catalyst::Exception->throw(
        message => "CGI invocation failed: $saved_error"
    ) if $saved_error;
  }

  return $env->response;
}

=head1 ACKNOWLEDGEMENTS

Original development sponsored by L<http://www.altinity.com/>

=head1 SEE ALSO

L<Catalyst::Controller::CGIBin>, L<CatalystX::GlobalContext>,
L<Catalyst::Controller>, L<CGI>, L<Catalyst>

=head1 AUTHOR

Matt S. Trout, C<< <mst at shadowcat.co.uk> >>

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

Copyright (c) 2008 Matt S. Trout

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Catalyst::Controller::WrapCGI

# vim: expandtab shiftwidth=2 ts=2 tw=80:
