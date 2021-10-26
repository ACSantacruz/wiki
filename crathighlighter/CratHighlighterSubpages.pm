package CratHighlighterSubpages;
use 5.006;
require Exporter;
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(gitCheck gitOnMain gitCleanStatus gitSHA mwLogin getUserAndPass dieNice botShutoffs getCurrentGroups getPageGroups cmpJSON changeSummary oxfordComma mapGroups usage);

#!/usr/bin/env perl
# cratHighlighterSubpages.pl by Amory Meltzer
# Licensed under the WTFPL http://www.wtfpl.net/
# Sync JSON lists for crathighlighter.js
# https://en.wikipedia.org/wiki/User:Amorymeltzer/crathighlighter
# Run via cron on toolforge as User:AmoryBot

use strict;
use warnings;
use English qw(-no_match_vars); # Avoid regex speed penalty in perl <=5.16

use Getopt::Long;
use FindBin qw($Bin);
use List::Util qw(uniqstr);

use JSON::MaybeXS;
use Log::Log4perl qw(:easy);
use Git::Repository;
use MediaWiki::API;
use File::Slurper qw(read_text write_text);


# Parse commandline options
my %opts = ();
GetOptions(\%opts, 'P', 'n', 'help|h|H' => \&usage);

# Figure out where this script is, if we're being run on the toolforge grid or not,
# if we're being run via cron (thanks to CRON=1 in crontab).  Also runs usage.
my ($scriptDir, $tool, $cron) = ($Bin, $ENV{LOGNAME} eq 'tools.amorybot', $ENV{CRON});

# Set up logger
# The full options are straightforward but overly verbose, and easy mode
# (with stealth loggers) is succinct and sufficient
my $infoLog =  { level  => $INFO,
		 file   => ">>$scriptDir/log.log",
		 utf8   => 1,
		 # Datetime (level): message
		 layout => '%d{yyyy-MM-dd HH:mm:ss} (%p): %m{indent}%n' };
# Only if not being run via cron
my $traceLog = { level  => $TRACE,
		 file   => 'STDOUT',
		 # message
		 layout => '%d - %m{indent}%n' };
Log::Log4perl->easy_init($cron ? $infoLog : ($infoLog, $traceLog));

# Pop into this script's directory, mostly so file access is simplified
chdir "$scriptDir" or LOGDIE('Failed to change directory');


### Check and update repo before doing anything unsupervised, i.e. via cron
if ($cron) {
  gitCheck();
}

### Initialize API object.  Get username/password combo, log in, etc.
my ($mw, $bot);
$mw = mwLogin();

### If it's the bot account, include a few checks for (emergency) shutoff
if ($tool) {
  botShutoffs();
}

### Get the current group information.  References since we want both a hash and
### an array back.  The @groups/$groups is only really used since I want an
### order to how items are returned to me, otherwise simply taking the keys of
### the hash would work just fine.
my ($groupsStore, $groups) = getCurrentGroups();

### Latest content of each on-wiki page
my %contentStore = getPageGroups(@{$groups});


### Main loop for each group
# These conveniently function as indicators as well as counters for number of
# files or pages changed, respectively
my ($localChange,$wikiChange) = (0,0);
my (@totAddedFiles, @totRemovedFiles, @totAddedPages, @totRemovedPages);
# Template for generating JSON, sorted
my $jsonTemplate = JSON->new->canonical(1);
$jsonTemplate = $jsonTemplate->indent(1)->space_after(1); # Make prettyish
foreach (@{$groups}) {
  my $note;
  my %queryHash = %{${$groupsStore}{$_}}; # Just the specific rights hash we want
  my $queryJSON; # JSON will only be built from the query if there are any updates

  # Check if local records have changed
  my $file = $_.'.json';
  my $fileJSON = read_text($file) or LOGDIE($ERRNO);
  my ($fileState, $fileAdded, $fileRemoved) = cmpJSON(\%queryHash, $jsonTemplate->decode($fileJSON));

  if ($fileState) {
    $localChange++;
    $note = "$file changed: ".changeSummary($fileAdded,$fileRemoved)."\n";

    # Build JSON from the received query now that we need it
    $queryJSON = $jsonTemplate->encode(\%queryHash);
    # Write changes, error handling weird: https://rt.cpan.org/Public/Bug/Display.html?id=114341
    write_text($file, $queryJSON);

    push @totAddedFiles, mapGroups($_, \@{$fileAdded});
    push @totRemovedFiles, mapGroups($_, \@{$fileRemoved});
  }

  # Check if on-wiki records have changed
  my $wikiJSON = $contentStore{$_}[1];
  my ($wikiState, $wikiAdded, $wikiRemoved) = cmpJSON(\%queryHash, $jsonTemplate->decode($wikiJSON));

  # Check if everything is up-to-date onwiki, optional push otherwise
  if ($wikiState) {
    $wikiChange++;
    my $summary = changeSummary($wikiAdded,$wikiRemoved);
    $note .= ($fileState ? 'and' : "$file").' needs updating on-wiki: '.$summary;

    push @totAddedPages, mapGroups($_, \@{$wikiAdded});
    push @totRemovedPages, mapGroups($_, \@{$wikiRemoved});

    if (!$opts{P}) {
      # Multifaceted and overly-verbose edit summaries are the best!
      my $editSummary = 'Update: '.$summary;
      # Include the count of the specific group
      my $count = scalar keys %queryHash;
      $editSummary .= " ($count total) (automatically via [[$bot/crathighlighter|script]])";
      $note .= '.  Pushing now... ';

      # Build JSON if not already done so above; only likely if the wiki is out
      # of date but the local files aren't for some reason
      $queryJSON ||= $jsonTemplate->encode(\%queryHash);
      $mw->edit({
		 action => 'edit',
		 assert => 'user',
		 title => $contentStore{$_}[0],
		 basetimestamp => $contentStore{$_}[2], # Avoid edit conflicts
		 text => $queryJSON,
		 summary => $editSummary
		});
      $note .= "$mw->{response}->{_msg}";
    } else {
      $note .= "\tSkipping push\n";
    }
  } elsif ($fileState) {
    $note .= "\tbut wiki already up-to-date";
  }

  # Log fully constructed message
  INFO($note) if $note;
}

# Clean up
$mw->logout();


# Also used for checking the previous run was successful
my $finalNote = $localChange + $wikiChange ? 'No further updates needed' : 'No updates needed';
INFO($finalNote);

# Report final status.  Each item should already be logged above in the main
# loop, this is just to trigger an email on changes when run via `cron`.
# Probably not needed long run, except to update the newsletter, but at least
# initially it's a good idea.
if ($localChange + $wikiChange) {
  my $updateNote = "CratHighlighter updates\n\n";

  # Include file/page code in first line? FIXME TODO
  # Might need to redo handling of totAdded*, mapGroups, etc.

  # Local changes
  if ($localChange) {
    $updateNote .= "Files: $localChange updated\n";
    if (scalar @totAddedFiles) {
      $updateNote .= "\tAdded: ".oxfordComma(uniqstr @totAddedFiles)."\n";
    }
    if (scalar @totRemovedFiles) {
      $updateNote .= "\tRemoved: ".oxfordComma(uniqstr @totRemovedFiles)."\n";
    }
  }

  # Notify on pushed changes
  if ($wikiChange) {
    $updateNote .= "Pages: $wikiChange ";
    if (!$opts{P}) {
      $updateNote .= "updated\n";
      if (scalar @totAddedPages) {
	$updateNote .= "\tAdded: ".oxfordComma(uniqstr @totAddedPages)."\n";
      }
      if (scalar @totRemovedPages) {
	$updateNote .= "\tRemoved: ".oxfordComma(uniqstr @totRemovedPages)."\n";
      }
    } else {
      $updateNote .= "not updated\n";
    }
  }

  print $updateNote;
}

# Useful if used when running after a failure, to ensure success on follow-up
if ($opts{n}) {
  print "Run completed\n";
}


######## SUBROUTINES ########


#### Usage statement ####
# Use POD or whatever?
# Escapes not necessary but ensure pretty colors
# Final line must be unindented?
sub usage {
  print <<"USAGE";
Usage: $PROGRAM_NAME [-hPn]
      -P Don't push live to the wiki
      -n Print a message to STDOUT upon completion of a successful run.  Useful for notifying after a prior failure.
      -h Print this message
USAGE
  exit;
}

