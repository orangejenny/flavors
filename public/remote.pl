#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;
use Flavors::Util;
use Flavors::Data::Collection;
use Flavors::Data::Playlist;
use Flavors::Data::Song;
use Flavors::Data::Tag;
use Flavors::Data::Util;
use JSON qw(to_json);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json");
my $fdat = Flavors::Util::Fdat($cgi);

my $sub = delete $fdat->{SUB};

my $dbh = Flavors::Data::Util::DBH();
#warn "DO THIS: $sub(\$dbh, \$fdat)";
my $results = eval("$sub(\$dbh, \$fdat)");
warn $@ if $@;

print JSON::to_json($results || {});
