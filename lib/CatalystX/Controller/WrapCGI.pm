package CatalystX::Controller::WrapCGI;

# AUTHOR: Matt S Trout, mst@shadowcatsystems.co.uk
# Original development sponsored by http://www.altinity.com/

use strict;
use warnings;
use base 'Catalyst::Controller';

use HTTP::Request::AsCGI;
use HTTP::Request;
use URI;

# Hack-around because Catalyst::Engine::HTTP goes and changes
# them to be the remote socket, and FCGI.pm does even dumber things.

open(*REAL_STDIN, "<&=".fileno(*STDIN));
open(*REAL_STDOUT, ">>&=".fileno(*STDOUT));

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

  $req->content($body_content);
  $req->content_length(length($body_content));
  my $user = (($c->can('user_exists') && $c->user_exists)
               ? eval { $c->user->obj->username }
                : '');
  my $env = HTTP::Request::AsCGI->new(
              $req,
              REMOTE_USER => $user,
              %ENV
            );

  {
    local *STDIN = \*REAL_STDIN;   # restore the real ones so the filenos
    local *STDOUT = \*REAL_STDOUT; # are 0 and 1 for the env setup

    my $old = select(REAL_STDOUT); # in case somebody just calls 'print'

    my $saved_error;

    $env->setup;
    eval { $call->() };
    $saved_error = $@;
    $env->restore;

    select($old);

    warn "CGI invoke failed: $saved_error" if $saved_error;

  }

  return $env->response;
}

1;
