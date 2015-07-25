#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my %icons = (
	rating => 'star',
	mood => 'heart',
	energy => 'fire',
);

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	TITLE => "Data",
});

print qq{ <div class="post-nav"> };

foreach my $facet (qw(rating energy mood)) {
	print sprintf(qq{
		<div class="rating-container" data-facet="%s">
			<i class="glyphicon glyphicon-%s"></i>
			<svg class="distribution"></svg>
			<svg class="unrated"></svg>
		</div>
	}, $facet, $icons{$facet});
}

print qq{ </div> };


print FlavorsHTML::Footer();
