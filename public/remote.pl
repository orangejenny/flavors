#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;
use JSON qw(to_json);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json");
my $fdat = FlavorsUtils::Fdat($cgi);

my $sub = delete $fdat->{SUB};
$fdat->{REF} = 1;

my $dbh = FlavorsData::DBH();
#warn "DO THIS: $sub(\$dbh, \$fdat)";
my $results = eval("$sub(\$dbh, \$fdat)");

print JSON::to_json($results) if $results;

