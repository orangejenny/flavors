#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

my $facet = $fdat->{FACET} || "rating";

Flavors::HTML::Header({
	FDAT => $fdat,
	TITLE => "Acquisitions",
	BUTTONS => Flavors::HTML::ExportControl() . Flavors::HTML::SelectionControl(),
	CSS => ['data.css'],
	JS => ['data.js', 'chart.js', 'acquisitions.js'],
});

print qq{
	<div class="post-nav">
		<div class="chart-container">
			<svg></svg>
		</div>
	</div>
};

print Flavors::HTML::Footer();
