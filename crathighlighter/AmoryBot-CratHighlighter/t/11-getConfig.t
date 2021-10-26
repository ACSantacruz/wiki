#!perl
# Test configuration options, including usernames and (mock) PW

use strict;
use warnings;

use AmoryBot::CratHighlighter qw(getConfig);
use Test::More tests => 9;
use Test::Exception; # Not really strictly necessary but helps avoid using eval


# Failures
throws_ok{getConfig} qr/No username provided/, 'No username fail';
throws_ok{getConfig({username=>'WrongUser'})} qr 'Wrong user provided', 'Wrong user';
throws_ok{getConfig({username=>'UserName', rcdir=>'../'})} qr/Wrong user provided/, 'Right test username but wrong directory';
throws_ok{getConfig({username=>'UserName', rcdir=>'../42'})} qr/Failed to change/, 'Nonexistent directory';
throws_ok{getConfig({username=>'UserName', rcdir=>'../../../'})} qr/No such file/, 'No rc config file';

# Cover lang, family, url FIXME TODO
# throws_ok{getConfig({username=>'UserName', lang=>'fr', family=>'wiktionary', url=>'https://fr.wiktionary.org/'})} qr/Meaningless/, 'Meaningless';


# Successes
my %UP = ('Username@oneScriptName.pl' => 'longstringof123456andA2Z',
	  'UserName@anotherScriptName.pl' => 'different1029384756StRiNg');

foreach my $name (sort keys %UP) {
  my $userName = $name =~ s/@.*//r;
  my $config = getConfig({username => $userName});
  is(${$config}{username}, $name, "Username - $name");
  is(${$config}{password}, $UP{$name}, "PW - $name");
}
