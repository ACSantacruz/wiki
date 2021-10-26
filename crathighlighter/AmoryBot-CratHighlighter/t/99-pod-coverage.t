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
# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
try {
  use Test::Pod::Coverage $min_tpc;
} catch {
  plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage";
}
# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
try {
  use Pod::Coverage $min_pc;
} catch {
  plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage";
}

all_pod_coverage_ok();
