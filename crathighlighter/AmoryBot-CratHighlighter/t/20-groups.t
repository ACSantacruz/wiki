#!/usr/bin/env perl
# Test non-ArbCom group processing

use strict;
use warnings;

use File::Slurper qw(read_text);
use JSON::MaybeXS;
use AmoryBot::CratHighlighter qw(findLocalGroupMembers);

use Test::More;

# List of each group, but for testing right now just a couple
my @rights = qw(bureaucrat interface-admin fakegroup);
my $localPerms = join q{|}, @rights;

my $count = scalar @rights;
plan tests => $count;

# Real deal
my @buro = ('Acalamari', 'AmandaNP', 'Avraham', 'Bibliomaniac15', 'Cecropia', 'Deskana', 'Dweller', 'MBisanz', 'Maxim', 'Nihonjoe', 'Primefac', 'SilkTork', 'UninvitedCompany', 'Useight', 'Warofdreams', 'WereSpielChequers', 'Worm That Turned', 'Xaosflux', 'Xeno');
my @inta = ('Amorymeltzer', 'Cyberpower678', 'Enterprisey', 'Evad37', 'Izno', 'MusikAnimal', 'MusikBot II', 'Oshwah', 'Ragesoss', 'Writ Keeper', 'Xaosflux');
my %actual = (bureaucrat => \@buro, 'interface-admin' => \@inta, fakegroup => []);

# Template for generating JSON, sorted
my $jsonTemplate = JSON->new->canonical(1);
$jsonTemplate = $jsonTemplate->indent(1)->space_after(1); # Make prettyish

my $file = 't/groups.json';
my $fileJSON = read_text($file);

my $groupsReturn = $jsonTemplate->decode($fileJSON);
my %groupsQuery = %{${$groupsReturn}{query}};
my @localHashes = @{$groupsQuery{allusers}};

# Will store hash of editors for each group.  Basically JSON as hash of hashes.
my %groupsData;
findLocalGroupMembers(\@localHashes, $localPerms, \%groupsData);

foreach my $userGroup (@rights) {
  my @users = sort keys %{$groupsData{$userGroup}};
  is_deeply(\@users, \@{$actual{$userGroup}}, $userGroup);
}
