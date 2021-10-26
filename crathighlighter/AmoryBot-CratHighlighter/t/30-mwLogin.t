#!perl
# Test logging in to the wiki

use strict;
use warnings;

use Test::More;
use AmoryBot::CratHighlighter qw(mwLogin);
use Test::Exception; # Not really strictly necessary but helps avoid using eval

# Requires hitting the API, so only enable when explicitly asked for
if ($ENV{API_TESTING} || $ENV{RELEASE_TESTING}) {
  plan tests => 3;
} else {
  plan skip_all => 'Skipping API tests';
}

my $mw;
throws_ok{mwLogin({username => 'UserName'})} qr/logging in/, 'Login failure';
lives_ok{$mw = mwLogin({username => 'Amorymeltzer', rcdir => '../'})} 'Right user username, right dir';
# $mw->logout();
lives_ok{$mw = mwLogin({username => 'AmoryBot', rcdir => '../'})} 'Right bot username, right dir';
# $mw->logout();
