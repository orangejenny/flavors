#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsData::Tags;
use FlavorsData::Utils;
use FlavorsHTML;

my $dbh = FlavorsData::Utils::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtils::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @tags = FlavorsData::Tags::List($dbh);
my $categorizeargs = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@tags,
});
$categorizeargs->{TABLE} = 'tagcategory';

print qq{ <div class="post-nav"> };

print FlavorsHTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print FlavorsHTML::Footer();
