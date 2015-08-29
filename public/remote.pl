#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;
use FlavorsUtils;
use FlavorsData::Collections;
use FlavorsData::Playlists;
use FlavorsData::Songs;
use FlavorsData::Tags;
use FlavorsData::Utils;
use JSON qw(to_json);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json");
my $fdat = FlavorsUtils::Fdat($cgi);

my $sub = delete $fdat->{SUB};
$fdat->{REF} = 1;

my $dbh = FlavorsData::Utils::DBH();
#warn "DO THIS: $sub(\$dbh, \$fdat)";
my $results = eval("$sub(\$dbh, \$fdat)");
warn $@ if $@;

print JSON::to_json($results) if $results;

