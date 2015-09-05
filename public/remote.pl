#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;
use FlavorsUtil;
use FlavorsData::Collection;
use FlavorsData::Playlist;
use FlavorsData::Song;
use FlavorsData::Tag;
use FlavorsData::Util;
use JSON qw(to_json);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json");
my $fdat = FlavorsUtil::Fdat($cgi);

my $sub = delete $fdat->{SUB};
$fdat->{REF} = 1;

my $dbh = FlavorsData::Util::DBH();
#warn "DO THIS: $sub(\$dbh, \$fdat)";
my $results = eval("$sub(\$dbh, \$fdat)");
warn $@ if $@;

print JSON::to_json($results) if $results;

