#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtil::Fdat($cgi);

FlavorsHTML::Header({
	FDAT => $fdat,
	TITLE => "Data",
	BUTTONS => FlavorsHTML::ExportControl() . FlavorsHTML::SelectionControl(),
	CSS => ['data.css', 'matrix.css'],
	JS => ['data.js', 'matrix.js'],
});

printf(qq{
		<div class="post-nav">
			<div class="post-nav-positioning">
				<div class="axis-label mood-high">%s</div>
				<div class="axis-label energy-high">%s</div>
				<div class="axis-label energy-low">%s</div>
				<div class="chart-container">
					<svg></svg>
				</div>
				<div class="axis-label mood-low">%s</div>
			</div>
		</div>
	},
	FlavorsHTML::Rating(5, 'heart'),
	FlavorsHTML::Rating(5, 'fire'),
	FlavorsHTML::Rating(1, 'fire'),
	FlavorsHTML::Rating(1, 'heart'),
);

print FlavorsHTML::Footer();
