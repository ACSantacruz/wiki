#!perl
# Test proper and pretty dying from MediaWiki::API

use strict;
use warnings;

use AmoryBot::CratHighlighter qw(dieNice);
use Test::More tests => 5;
use Test::Exception;

# Fake it
my $mw;
$mw->{error}->{code} = 0;
$mw->{error}->{details} = 'Success';

throws_ok{dieNice($mw)} qr/MediaWiki error:\n0: Success/, 'Test var not present';

foreach my $err (2..5) {
  $mw->{error}->{code} = $err;
  $mw->{error}->{details} = "Test$err";
  throws_ok{dieNice($mw)} qr/MediaWiki error: .*?:\n$mw->{error}->{code}: $mw->{error}->{details}/, "$mw->{error}->{code} test";
}
