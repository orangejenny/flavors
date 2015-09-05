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

my $facet = $fdat->{FACET} || "rating";
my %icons = (
	rating => 'star',
	mood => 'heart',
	energy => 'fire',
);

FlavorsHTML::Header({
	FDAT => $fdat,
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportControl() . FlavorsHTML::SelectionControl(),
	CSS => ['data.css', 'facet.css'],
	JS => ['data.js', 'facet.js'],
});

print qq{ <div class="post-nav"> };

# Distribution and rated/unrated chart
printf(qq{ <div class="distribution-container" data-facet="%s"> }, $facet);
print qq{ <svg class="distribution"></svg> };
print qq{ <div class='axis'> };
foreach my $i (1..5) {
	printf("<span class='axis-label'>%s</span>", FlavorsHTML::Rating($i, $icons{$facet}));
}
print qq{ </div> };

print qq{ <svg class="unrated"></svg> };
print qq{ </div> };

# Toolbar
my @categories = FlavorsData::Tag::CategoryList($dbh);
push(@categories, "genres");
print "<div class='btn-group category-buttons'>";
foreach my $category (sort @categories) {
	printf("<button class='btn btn-default' data-category='%s'>%s</button>", $category, $category);
}
print "</div>";

# Category charts
print qq{ <div> };
print sprintf(qq{
	<div class="category-container" data-facet="%s">
		<svg></svg>
	</div>
}, $facet, $icons{$facet});
print qq{ </div> };

print qq{ </div> };	# .post-nav


print FlavorsHTML::Footer();
