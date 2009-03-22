#!perl

use strict;
use warnings;

use Test::More tests => 1;

{
    package TestApp;

    use Catalyst;
    use CatalystX::GlobalContext ();

    sub auto : Private {
        my ($self, $c) = @_;
        CatalystX::GlobalContext->set_context($c);
        1;
    }

    sub dummy : Local {
        my ($self, $c) = @_;
        $c->res->body(Dongs->foo);
    }

    __PACKAGE__->setup;
    
    package Dongs;

    use CatalystX::GlobalContext '$c';

    sub foo { $c->action }
}

use Catalyst::Test 'TestApp';

is(get('/dummy'), 'dummy', 'global context works');
