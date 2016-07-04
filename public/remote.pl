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
my $fh = $cgi->param('jls');
warn "fh=" . $fh;
#warn "START CGI";
#warn $cgi->param('id');
#warn $cgi->param('sub');
#warn "END CGI";
print $cgi->header(-type => "application/json");
my $fdat = Flavors::Util::Fdat($cgi);
#my $fdat = {};

#begin
my $buffer;
open(OUTPUT, ">images/collections/" . $fdat->{ID} . ".png") || die "Can't create local file: $!";

binmode($fh);
binmode(OUTPUT);

while ( read($fh, $buffer, 16384)) {
    print OUTPUT $buffer;
}
#end

use Data::Dumper;
#warn "ID=" . $fdat->{ID};
#warn "SUB=" . $fdat->{SUB};
warn Dumper(keys %$fdat);


my $sub = delete $fdat->{SUB};

my $dbh = Flavors::Data::Util::DBH();
my $results = eval("$sub(\$dbh, \$fdat)");
warn $@ if $@;

print JSON::to_json($results || {});
