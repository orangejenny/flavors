#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;
use Flavors::Data::Playlist;
use Flavors::Data::Util;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

Flavors::HTML::Header({
    CSS => ['colors.css'],
    JS => ['colors.js'],
    SPINNER => 1,
});

my @playlists = Flavors::Data::Playlist::List($dbh, {
});

print qq{ <div class="post-nav"> };

print qq{
    melancholia
};

print qq{ </div> };
print Flavors::HTML::Footer();
