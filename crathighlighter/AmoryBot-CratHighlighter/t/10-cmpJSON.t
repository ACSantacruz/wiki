#!/usr/bin/env perl
# Test comparison of different JSON bodies

use strict;
use warnings;

use File::Slurper qw(read_text);
use JSON::MaybeXS;

use AmoryBot::CratHighlighter qw(cmpJSON);
use Test::More;

# List users from each group.  Essentially cribbed from file.t, but without the
# one overlapper (Xaosflux)
my @buro = ('Acalamari', 'AmandaNP', 'Avraham', 'Bibliomaniac15', 'Cecropia', 'Deskana', 'Dweller', 'MBisanz', 'Maxim', 'Nihonjoe', 'Primefac', 'SilkTork', 'UninvitedCompany', 'Useight', 'Warofdreams', 'WereSpielChequers', 'Worm That Turned', 'Xeno');
my @inta = ('Amorymeltzer', 'Cyberpower678', 'Enterprisey', 'Evad37', 'Izno', 'MusikAnimal', 'MusikBot II', 'Oshwah', 'Ragesoss', 'Writ Keeper');

# Template for generating JSON, sorted
my $jsonTemplate = JSON->new->canonical(1);
$jsonTemplate = $jsonTemplate->indent(1)->space_after(1); # Make prettyish

my $file = 't/file.json';
my $fileJSON = read_text($file);

my $contentReturn = $jsonTemplate->decode($fileJSON);
# Stores page title, content, and last edited time in an array for each group
my %contentData;
# This monstrosity results in an array where each item is an array of hashes:
## title     -> used to also snag the specific group used for hash key
## revisions -> array containing one item, which is a hash, which has keys:
### content   -> full page content
### timestamp -> time last edited
# Just awful.  Then again, it could be made even worse!
foreach my $pageHash (@{${${$contentReturn}{query}}{pages}}) {
  my $userGroup = ${$pageHash}{title} =~ s/.*\.js\/(.+)\.json/$1/r;
  my @revisions = @{${$pageHash}{revisions}};
  $contentData{$userGroup} = [${$pageHash}{title},${$revisions[0]}{content},${$revisions[0]}{timestamp}];
}

my %hash;	 # Sigh FIXME TODO
# Name of test points to array:
## First two items: Parameters passed to cmpJSON
## Last two are expected added/removed array refs, respectively
my %tests = (
	     actual => [$jsonTemplate->decode($contentData{bureaucrat}[1]), $jsonTemplate->decode($contentData{'interface-admin'}[1]), \@buro, \@inta],
	     identical => [($jsonTemplate->decode($contentData{'bureaucrat'}[1]))x2, ([])x2],
	     empty => [(\%hash)x2, ([])x2]
	    );

my $count = scalar keys %tests;
plan tests => $count*3;

foreach my $test (sort keys %tests) {
  my ($fileState, $fileAdded, $fileRemoved) = cmpJSON($tests{$test}[0], $tests{$test}[1]);
  is($fileState, $test eq 'actual', "$test - Accurate state");
  is_deeply(\@{$fileAdded}, \@{$tests{$test}[2]}, "$test - Added");
  is_deeply(\@{$fileRemoved}, \@{$tests{$test}[3]}, "$test - Added");
}
