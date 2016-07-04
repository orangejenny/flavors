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
my $fh = $cgi->param('file');
print $cgi->header(-type => "application/json");
my $fdat = Flavors::Util::Fdat($cgi);

my $buffer;
open(OUTPUT, ">images/collections/" . $fdat->{ID} . ".png") || die "Can't create local file: $!";

binmode($fh);
binmode(OUTPUT);

while ( read($fh, $buffer, 16384)) {
    print OUTPUT $buffer;
}

my $sub = delete $fdat->{SUB};

my $dbh = Flavors::Data::Util::DBH();
my $results = eval("$sub(\$dbh, \$fdat)");
warn $@ if $@;

print JSON::to_json($results || {});
