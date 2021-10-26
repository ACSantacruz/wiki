#!perl
# Ensure the Git repository is clean and on the right branch

use strict;
use warnings;
use Test::More;

# Only enable on toolforge or when explicitly testing
if ($ENV{LOGNAME} eq 'tools.amorybot' || $ENV{RELEASE_TESTING}) {
  plan tests => 3;
} else {
  plan skip_all => 'Tests annoying when developing';
}

use AmoryBot::CratHighlighter qw(gitOnMain gitCleanStatus gitSHA);
require Git::Repository;

my $repo = Git::Repository->new();

ok(!gitOnMain($repo), 'On main branch');
ok(!gitCleanStatus($repo), 'Repository is clean');
ok(gitSHA($repo), 'Get a SHA');
