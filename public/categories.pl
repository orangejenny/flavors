#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsData::Tag;
use FlavorsData::Util;
use FlavorsHTML;

my $dbh = FlavorsData::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtil::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['categories.css'],
	JS => ['categories.js'],
});

my @tags = FlavorsData::Tag::List($dbh);
my $categorizeargs = FlavorsUtil::Categorize($dbh, {
	ITEMS => \@tags,
});
$categorizeargs->{TABLE} = 'tagcategory';

print qq{ <div class="post-nav"> };

print FlavorsHTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print FlavorsHTML::Footer();
