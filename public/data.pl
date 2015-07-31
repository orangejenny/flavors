#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my @facets = qw(rating energy mood);
my %icons = (
	rating => 'star',
	mood => 'heart',
	energy => 'fire',
);

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportButton() . qq{
		<button class="btn btn-info btn-xs hide clear-button">
			<i class="glyphicon glyphicon-remove"></i>
			Clear Selection
		</button>
	},
});

print qq{ <div class="post-nav"> };

# Distribution and rated/unrated charts
foreach my $facet (@facets) {
	print sprintf(qq{
		<div class="rating-container" data-facet="%s">
			<i class="glyphicon glyphicon-%s"></i>
			<svg class="distribution"></svg>
			<svg class="unrated"></svg>
		</div>
	}, $facet, $icons{$facet});
}

# Toolbar
my @categories = FlavorsData::CategoryList($dbh);
push(@categories, "genres");
print "<div class='btn-group category-buttons'>";
foreach my $category (sort @categories) {
	printf("<button class='btn btn-default' data-category='%s'>%s</button>", $category, $category);
}
print "</div>";

# Category charts
print qq{ <div> };
foreach my $facet (@facets) {
	print sprintf(qq{
		<div class="category-container" data-facet="%s">
			<svg></svg>
		</div>
	}, $facet, $icons{$facet});
}
print qq{ </div> };

print qq{ </div> };	# .post-nav


print FlavorsHTML::Footer();
