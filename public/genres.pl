#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;
use Flavors::Data::Tag;
use Flavors::Data::Util;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

Flavors::HTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @artists = Flavors::Data::Tag::ArtistGenreList($dbh);
my $categorizeargs = Flavors::Util::Categorize($dbh, {
	ITEMS => \@artists,
});
$categorizeargs->{TABLE} = 'artistgenre';

print qq{ <div class="post-nav"> };

print Flavors::HTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print Flavors::HTML::Footer();
