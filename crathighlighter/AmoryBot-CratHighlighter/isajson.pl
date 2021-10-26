#!/usr/bin/env perl
# isajson by Amory Meltzer

use strict;
use warnings;
use English qw(-no_match_vars); # Avoid regex speed penalty in perl <=5.16

use diagnostics; # Remove after development;

use JSON::MaybeXS;

# Template for generating JSON, sorted
my $jsonTemplate = JSON->new->canonical(1);
$jsonTemplate = $jsonTemplate->indent(1)->space_after(1); # Make prettyish

use Test::More;
isa_ok($jsonTemplate, 'Cpanel::JSON::XS', 'raw text');
isa_ok($jsonTemplate, JSON::MaybeXS::JSON(), 'constructor');
use feature 'say';
say ref $jsonTemplate;
