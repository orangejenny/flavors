#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;
use FlavorsData::Tags;
use FlavorsData::Utils;

my $dbh = FlavorsData::Utils::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtils::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @artists = FlavorsData::Tags::ArtistGenreList($dbh);
my $categorizeargs = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@artists,
});
$categorizeargs->{TABLE} = 'artistgenre';

print qq{ <div class="post-nav"> };

print FlavorsHTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print FlavorsHTML::Footer();
