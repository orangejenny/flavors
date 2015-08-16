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

my $facet = $fdat->{FACET} || "rating";

FlavorsHTML::Header({
	FDAT => $fdat,
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportControl() . FlavorsHTML::SelectionControl(),
	CSS => ['data.css', 'matrix.css'],
	JS => ['data.js', 'matrix.js'],
});

printf(qq{
		<div class="post-nav">
			<div class="axis-label mood-high">%s</div>
			<div class="axis-label energy-high">%s</div>
			<div class="axis-label energy-low">%s</div>
			<div class="chart-container">
				<svg></svg>
			</div>
			<div class="axis-label mood-low">%s</div>
		</div>
	},
	FlavorsHTML::Rating(5, 'heart'),
	FlavorsHTML::Rating(5, 'fire'),
	FlavorsHTML::Rating(1, 'fire'),
	FlavorsHTML::Rating(1, 'heart'),
);

print FlavorsHTML::Footer();
