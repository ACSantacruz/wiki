#!/usr/bin/env perl
# Tests for ArbCom template processing

use strict;
use warnings;

use AmoryBot::CratHighlighter qw(findArbComMembers);
use File::Slurper qw(read_text);
use Test::More;

my @testFiles = ('members.txt', 'members_former.txt', 'members_elect.txt');
my $count = scalar @testFiles;
plan tests => $count;

# Official list compared to testing pages, minor changes to handle sorting
# differences and resignations
my @arbcom = ('Beeblebrox', 'Bradv', 'Casliber', 'DGG', 'David Fuchs', 'GorillaWarfare', 'Joe Roe', 'KrakatoaKatie', 'Maxim', 'Mkdw', 'Newyorkbrad', 'SoWhy', 'Worm That Turned', 'Xeno');

foreach my $file (@testFiles) {
  is_deeply(parseContent("t/$file"), \@arbcom, "$file");
}

# Rough approximation of the processing function in the main script, adapted to
# use local files.  Basically, slurp file contents into a single handle (mimicking
# API response) then pass a clean data hash.  Overkill here, but comparable.
sub parseContent {
  my $ac = read_text(shift);
  my %groupsData;
  findArbComMembers($ac, \%groupsData);

  # haha arrayref
  return [sort keys %{$groupsData{arbcom}}];
}
