#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtils::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @tags = FlavorsData::TagList($dbh);
my $categorizeargs = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@tags,
});
$categorizeargs->{TABLE} = 'tagcategory';

print qq{ <div class="post-nav"> };

print FlavorsHTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print FlavorsHTML::Footer();
