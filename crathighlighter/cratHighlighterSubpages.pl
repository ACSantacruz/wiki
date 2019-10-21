#!/usr/bin/env perl
# cratHighlighterSubpages.pl by Amory Meltzer
# Licensed under the WTFPL http://www.wtfpl.net/
# Make it easier to sync crathighlighter.js
# https://en.wikipedia.org/wiki/User:Amorymeltzer/crathighlighter.js

use strict;
use warnings;
use diagnostics;

use Getopt::Std;
use Config::General qw(ParseConfig);
use MediaWiki::API;
use Git::Repository;
use File::Slurper qw(write_text);
use File::Compare;


# Check repo before doing anything risky
my $repo = Git::Repository->new();
if ($repo->run('rev-parse' => '--abbrev-ref', 'HEAD') ne 'master') {
  print "Not on master branch, quitting\n";
  exit 0;
} elsif (scalar $repo->run(status => '--porcelain')) {
  print "Repository is not clean, quitting\n";
  exit;
}

# Quick dumb check for internet connection, everything empty otherwise
# Could probably subroutine a curl check, but meh
my $ip = `curl -s 'icanhazip.com'`;
if (!$ip) {
  print "No internet connection found, quitting\n";
  exit 0;
}

# Parse commandline options
my %opts = ();
getopts('hpc', \%opts);
if ($opts{h}) { usage(); exit; } # Usage

# Config file should be a simple file consisting of username and botpassword
# username = Jimbo Wales
# password = stochasticstring
my %conf;
my $config_file = "$ENV{HOME}/.crathighlighterrc";
%conf = ParseConfig($config_file) if -e -f -r $config_file;

my $mw = MediaWiki::API->new({
			      api_url => 'https://en.wikipedia.org/w/api.php'
			     });
$mw->{ua}->agent('cratHighlighterSubpages.pl ('.$mw->{ua}->agent.')');
$mw->login({lgname => $conf{username}, lgpassword => $conf{password}})
  or die "Error logging in: $mw->{error}->{code}: $mw->{error}->{details}\n";

my ($localChange,$wikiChange) = (0,0);
my @rights = qw (bureaucrat oversight checkuser interface-admin arbcom steward);
foreach (@rights) {
  my @names;

  my $file = $_.'.json';

  if (/arbcom/) {
    # Imperfect, relies upon the template being updated, but ArbCom membership
    # is high-profile enough that it will likely be updated quickly
    my $page = $mw->get_page({title => 'Template:Arbitration_committee_chart/recent'});
    my $content = $page->{q{*}};

    # Find the diamonds in the rough
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime;
    $year += 1900;
    # 0-padding
    $mon = sprintf '%02d', $mon+1;
    $mday = sprintf '%02d', $mday;
    my $now = $year.q{-}.$mon.q{-}.$mday;
    last if $now =~ /-12-31/; # For dumb template reasons, arbs are listed
                              # as ending terms on December 30th.  While
                              # unlikely, this means the list won't be
                              # accurate on the 31st, so just skip it.
    for (split /^/, $content) {
      if (/from:(\d{2}\/\d{2}\/\d{4}) till:(\d{2}\/\d{2}\/\d{4}).*\[\[User:.*\|(.*)\]\]/) {
	my ($from,$till,$name) = ($1,$2,$3);
	$from =~ s/(\d{2})\/(\d{2})\/(\d{4})/$3-$1-$2/;
	$till =~ s/(\d{2})\/(\d{2})\/(\d{4})/$3-$1-$2/;
	if ($from le $now && $till gt $now) {
	  push @names, $name;
	}
      }
    }
  } else {
    # Everybody!  Everybody!
    my $query = {
		 action => 'query',
		 format => 'json',
		 utf8 => '1'
		};

    if (/steward/) {
      ${$query}{list} = 'globalallusers';
      ${$query}{agulimit} = 'max';
      ${$query}{agugroup} = $_;
    } else {
      ${$query}{list} = 'allusers';
      ${$query}{aulimit} = 'max';
      ${$query}{augroup} = $_;
    }

    # Usernames from reference to array of hash references
    my $ret = $mw->list($query) || die "$mw->{error}->{code}: $mw->{error}->{details}\n";
    @names = map {$_->{name}} @{$ret};
  }

  my $json = '{';
  foreach (sort @names) {
    $json .= "\n    \"$_\": 1";
    if ($_ ne (sort @names)[-1]) {
      $json.= q{,};
    }
  }
  $json .= "\n}";

  write_text($file, $json);
  my $status = $repo->run(status => $file, '--porcelain', {cwd => undef});
  if ($status) {
    $localChange = 1;
    print "$file changed\n\t";
  }

  # Check that everything is up-to-date onwiki, push otherwise
  my $pTitle = "User:Amorymeltzer/crathighlighter.js/$file";
  my $getPage = $mw->get_page({title => $pTitle}) or die "$mw->{error}->{code}: $mw->{error}->{details}\n";

  my $wikiSon = $getPage->{q{*}};
  my $wiki = $_.'.wiki';
  write_text($wiki, $wikiSon);

  # Check if wiki is different than local
  if ($repo->run(status => $wiki, '--porcelain', {cwd => undef})) {
    $wikiChange = 1;
    # Now that the .json files are up-to-date, check if there's actually a difference
    if (compare("$file","$wiki") != 0) {
      write_text($wiki, $json); # Not any more!

      if ($status) {
	print 'and';
      } else {
	print "$file"
      }
      print " needs updating on-wiki.\n";

      if ($opts{p}) {
	$repo->run(reset => 'HEAD', q{--}); # Clear staging area just in case
	$repo->run(add => '*.wiki');
	my ($plusRef, $minusRef) = plusMinus($repo, $wiki);
	my $changes = buildSummary($plusRef,$minusRef);

	my $summary = 'Update ';
	if (length $changes) {
	  $summary .= '('.$changes.') ';
	}
	$summary .='(automatically via [[User:Amorymeltzer/scripts#crathighlighter.js|script]])';
	my $timestamp = $getPage->{timestamp};

	print "\tPushing now...\n";
	$mw->edit({
		   action => 'edit',
		   title => $pTitle,
		   basetimestamp => $timestamp, # Avoid edit conflicts
		   text => $json,
		   summary => $summary
		  }) || die "Error editing the page: $mw->{error}->{code}: $mw->{error}->{details}\n";
	my $return = $mw->{response};
	print "\t$return->{_msg}\n";
	$repo->run(reset => 'HEAD', q{--}); # Back to clean staging area
      }
    } elsif ($status) {
      print "but already up-to-date\n";
    }
  }
}

if ($localChange == 0 && $wikiChange == 0) {
  print "No updates needed\n";
} else {
  system 'growlnotify -t "cratHighlighter" -m "Changes or updates made"';

  # Autocommit changes
  if ($opts{c}) {
    my $commitMessage = "cratHighlighterSubpages: Update\n";
    $repo->run(reset => 'HEAD', q{--}); # Clear staging area just in case
    $repo->run(add => '*.wiki'); # Always

    # Autocommit json changes
    if ($localChange == 1) {
      $repo->run(add => '*.json');
      my @cached = $repo->run(diff => '--name-only', '--staged');
      if (@cached) {

	# Build file abbreviation hash
	my %abbrevs;
	while (<DATA>) {
	  chomp;
	  my @map = split;
	  $abbrevs{$map[0]} = $map[1];
	}

	# Build message and commit
	foreach (sort @cached) {
	  s/.*\/(\S+\.json).*/$1/;
	  $commitMessage .= "\n$abbrevs{$_}";

	  my ($plusRef, $minusRef) = plusMinus($repo, $_);
	  my $changes = buildSummary($plusRef,$minusRef);
	  if (length $changes) {
	    $commitMessage .= ' ('.$changes.')';
	  }
	}
      }
    }

    my @cached = $repo->run(diff => '--name-only', '--staged');
    if (@cached) {
      # Someone else changed json files on-wiki
      if ($wikiChange == 1) {
	$commitMessage .= "\nUpdated local backups of on-wiki files";
      }
      # Commit
      $repo->run(commit => '-m', "$commitMessage");
    }
  }
}


#### SUBROUTINES
# Process diff for usernames of added/removed.  Flag for cached or not
sub plusMinus {
  my ($r,$f) = @_;
  my (@p,@m);

  my $cmd = $r->command(diff => '--staged', q{--}, "$f", {cwd => undef});
  my $s = $cmd->stdout;
  if (!eof $s) { # Some output even exists
    while (<$s>) {
      if (/^[+-].+": 1,/) { # We know what the important lines look like, so abuse that
	chomp;
	my $name = s/([+-])\s+"(.*)": 1,.*/$1$2/r;
	my @map = split //, $name, 2;
	if ($map[0] eq '+') {
	  push @p, $map[1];
	} elsif ($map[0] eq '-') {
	  push @m, $map[1];
	}
      }
    }
    $cmd->close;
    return (\@p, \@m);
  }
}

# Create a commit/edit summary from the plus/minus in a diff.
# Uses oxfordComma below for proper grammar
# This could be part of plusMinus, but I like having it separate, even if it
# means dealing with a few more references
sub buildSummary {
  my ($pRef,$mRef) = @_;
  my $change;

  if ($pRef && ${$pRef}[0]) {
    $change .= 'Added '.oxfordComma(@{$pRef});
  }
  if ($mRef && ${$mRef}[0]) {
    if (length $change) {
      $change .= '; ';
    }
    $change .= 'Removed '.oxfordComma(@{$mRef});
  }

  return $change;
}

# Oxford comma
sub oxfordComma {
  my @list = @_;
  my $end = pop @list;
  if (@list) { # More than one
    my $ox = q{};
    if (scalar @list > 1) { # More than two, need an oxford comma
      $ox = q{,};
    }
    return join(', ', @list) . "$ox and $end";
  } else { # Just one entry
    return $end;
  }
}

#### Usage statement ####
# Use POD or whatever?
# Escapes not necessary but ensure pretty colors
# Final line must be unindented?
sub usage {
  print <<USAGE;
Usage: $0 [-hpc]
      -p Push live to wiki
      -c Automatically commit changes in git
      -h print this message
USAGE
  return;
}


## The lines below do not represent Perl code, and are not examined by the
## compiler.  Rather, they are used by %deploys to map filenames from the
## Twinkle git repo to their corresponding location in the MediaWiki Gadget
## psuedonamespace.
__DATA__
arbcom.json AC
  bureaucrat.json B
  checkuser.json CU
  interface-admin.json IA
  oversight.json OS
  steward.json SW
