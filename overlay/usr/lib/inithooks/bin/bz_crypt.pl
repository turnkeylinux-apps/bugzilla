#!/usr/bin/perl

use lib "/usr/share/bugzilla3";
use Bugzilla;
use Bugzilla::Util;

if ($#ARGV != 0 ) {
	print "usage: $0 <string>\n";
	exit;
}

my $cryptstr = bz_crypt($ARGV[0]);
print "$cryptstr\n";
