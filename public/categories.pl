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
my $task = $fdat->{TASK} || 'categories';	# qw(categories genres colors)

FlavorsHTML::Header({
	CSS => $task eq 'colors' ? ['/css/thirdparty/jquery.miniColors.css'] : [],
	JS => $task eq 'colors' ? ['/javascript/thirdparty/jquery.miniColors.js'] : [],
});

print qq{ <div class="post-nav"> };
if ($task eq 'categories') {
	my @tags = FlavorsData::TagList($dbh);
	my $categorizedtags = FlavorsUtils::Categorize($dbh, {
		ITEMS => \@tags,
	});
	print FlavorsHTML::Categorize($dbh, $categorizedtags),
}
elsif ($task eq 'genres') {
	my @artists = FlavorsData::ArtistGenreList($dbh);
	my $categorizedartists = FlavorsUtils::Categorize($dbh, {
		ITEMS => \@artists,
	});
	print FlavorsHTML::Categorize($dbh, $categorizedartists),
}
else {
	my @colors = FlavorsData::ColorList($dbh);
	foreach my $color (@colors) {
		printf(qq{
				<div class="color">
					<div class="name">%s</div>
					<input type="minicolors" data-slider="wheel" value="#%s" data-textfield="false">
					<div class="btn-group white-text" data-toggle="buttons-radio">
						<button class="btn btn-xs btn-default%s" value="0">black text</button>
						<button class="btn btn-xs btn-default%s" value="1">white text</button>
					</div>
				</div>
			},
			$color->{NAME},
			$color->{HEX},
			$color->{WHITETEXT} ? "" : " active",
			$color->{WHITETEXT} ? " active" : "",
		);
	}
}

print qq{ </div> };
print FlavorsHTML::Footer();
