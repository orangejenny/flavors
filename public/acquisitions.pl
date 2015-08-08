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
	CSS => ['data.css', 'acquisitions.css'],
	JS => ['data.js', 'acquisitions.js'],
});

print qq{
	<div class="post-nav">
		<div class="chart-container">
			<svg></svg>
			<div id="max-year" class="pull-right"></div>
			<div id="min-year" class="pull-left"></div>
		</div>
	</div>
};

print FlavorsHTML::Footer();
