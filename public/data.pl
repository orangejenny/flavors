#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	TITLE => "Data",
});

print qq{ <div class="post-nav"> };

foreach my $facet (qw(rating mood energy)) {
	print sprintf(qq{
		<div class="rating-container" data-facet="%s">
			<svg class="ratings"></svg>
			<div class="x-axis">%s</div>
		</div>
	}, $facet, $facet);
}

print qq{ </div> };


print FlavorsHTML::Footer();