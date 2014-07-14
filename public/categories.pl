#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({ HIDEEXPORT => 1 });

my @tags = FlavorsData::TagList($dbh);
my $categorizedtags = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@tags,
});

my @artists = FlavorsData::ArtistGenreList($dbh);
my $categorizedartists = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@artists,
});

my @colors = FlavorsData::ColorList($dbh);

print qq{
	<link href="/css/jquery.miniColors.css" rel="stylesheet" type="text/css" />
	<script type="text/javascript" src="/javascript/jquery.miniColors.js"></script>
	<div class="post-nav">
};

my $colorscontent = "";
foreach my $color (@colors) {
	$colorscontent .= sprintf(qq{
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

printf(qq{
		<ul class="nav nav-tabs">
			<li class="active"><a data-toggle="tab" href="#tag-category">Tags &rArr; Categories</a></li>
			<li><a data-toggle="tab" href="#artist-genre">Artists &rArr; Genres</a></li>
			<li><a data-toggle="tab" href="#colors">Colors</a></li>
		</ul>

		<div class="tab-content">
			<div class="tab-pane active" id="tag-category">%s</div>
			<div class="tab-pane" id="artist-genre">%s</div>
			<div class="tab-pane" id="colors">%s</div>
		</div>
	},
	FlavorsHTML::Categorize($dbh, $categorizedtags),
	FlavorsHTML::Categorize($dbh, $categorizedartists),
	$colorscontent,
);

print qq{ </div> };
print FlavorsHTML::Footer();
