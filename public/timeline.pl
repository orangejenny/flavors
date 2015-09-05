#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtil::Fdat($cgi);

my $facet = $fdat->{FACET} || "rating";

FlavorsHTML::Header({
	FDAT => $fdat,
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportControl() . FlavorsHTML::SelectionControl(),
	CSS => ['data.css'],
	JS => ['data.js', 'timeline.js'],
});

print qq{
	<div class="post-nav">
		<div class="timeline-container">
			<svg></svg>
		</div>
	</div>
};

print FlavorsHTML::Footer();
