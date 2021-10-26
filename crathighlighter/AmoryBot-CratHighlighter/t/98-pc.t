#!perl
# Perl::Critic tests

use strict;
use warnings;
use Test::More;

# Only enable on toolforge or when explicitly testing
if (!$ENV{RELEASE_TESTING}) {
  plan( skip_all => 'Perl::Critic tests not done when developing' );
}

# Defaults to 5, only showing the most severe.  Fine.
require Test::Perl::Critic;
Test::Perl::Critic->import();
# plan tests => 7;
all_critic_ok('cratHighlighterSubpages.pl', 't/');
