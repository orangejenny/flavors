#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;
use FlavorsData::Tag;
use FlavorsData::Util;

my $dbh = FlavorsData::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtil::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @artists = FlavorsData::Tag::ArtistGenreList($dbh);
my $categorizeargs = FlavorsUtil::Categorize($dbh, {
	ITEMS => \@artists,
});
$categorizeargs->{TABLE} = 'artistgenre';

print qq{ <div class="post-nav"> };

print FlavorsHTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print FlavorsHTML::Footer();
