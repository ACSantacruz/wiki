#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => 'Author tests not required for installation' );
}

require Try::Tiny;
Try::Tiny->import();
# Ensure a recent version of Test::Pod
my $min_tp = 1.22;
try {
  use Test::Pod $min_tp;
} catch {
  plan skip_all => "Test::Pod $min_tp required for testing POD";
}

all_pod_files_ok();
