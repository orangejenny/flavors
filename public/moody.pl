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
my %icons = (
	rating => 'star',
	mood => 'heart',
	energy => 'fire',
);

FlavorsHTML::Header({
	FDAT => $fdat,
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportControl() . FlavorsHTML::SelectionControl(),
	CSS => ['data.css'],
	JS => ['data.js', 'moody.js'],
});

print qq{
	<div class="post-nav">
		<div class="chart-container">
			<svg></svg>
		</div>
	</div>
};

print FlavorsHTML::Footer();
