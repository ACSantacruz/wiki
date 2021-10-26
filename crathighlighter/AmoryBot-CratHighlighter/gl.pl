#!/usr/bin/env perl
# gl by Amory Meltzer

use strict;
use warnings;
use English qw(-no_match_vars); # Avoid regex speed penalty in perl <=5.16

use diagnostics; # Remove after development;

use AmoryBot::CratHighlighter qw(gitCheck);
use Log::Any::Adapter;
use Log::Log4perl qw(:easy);
use FindBin qw($Bin);
Log::Log4perl->easy_init(
			 { level  => $INFO,
		 file   => ">>$Bin/log.log",
		 utf8   => 1,
		 # Datetime (level): message
		 layout => '%d{yyyy-MM-dd HH:mm:ss} (%p): %m{indent}%n' }
			);
# Log::Any::Adapter->set('Log4perl');
use Log::Any::Adapter ('File', "$Bin/loga.log");
gitCheck();
