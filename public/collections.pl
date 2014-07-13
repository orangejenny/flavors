#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;
use POSIX qw(strftime);

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtils::Fdat($cgi);
FlavorsHTML::Header({
	TITLE => "Collections",
});

my @collections = FlavorsData::CollectionList($dbh);
my %songs;
my @songs = FlavorsData::SongList($dbh);
foreach my $song (@songs) {
	$songs{$song->{ID}} = $song;
}
my @tracks = FlavorsData::TrackList($dbh);
my %tracks;
foreach my $song (@tracks) {
	if (!exists $tracks{$song->{COLLECTIONID}}) {
		$tracks{$song->{COLLECTIONID}} = [];
	}
	push(@{ $tracks{$song->{COLLECTIONID}} }, $song);
}

print qq{
	<div class="controls">
		Collections:
		<input type="text" id="collection-filter">
		Tags:
		<input type="text" id="tag-filter">
		<div class="dropdown sort-menu">
			Sort by
			<a class="dropdown-toggle" data-toggle="dropdown" role="label" href="#">
				<span class="current">Date Acquired</span>
				<b class="caret"></b>
			</a>
			<ul class="dropdown-menu">
				<li><a href="#">Artist</a></li>
				<li><a href="#">Energy</a></li>
				<li><a href="#">Export Count</a></li>
				<li><a href="#">Last Export</a></li>
				<li><a href="#">Mood</a></li>
				<li><a href="#">Name</a></li>
				<li><a href="#">Rating</a></li>
			</ul>
		</div>
		<br>
		<div id="is-mix">
			<label>
				<input type="checkbox" value="0" checked>
				Albums
			</label>
			<label>
				<input type="checkbox" value="1" checked>
				Mixes
			</label>
		</div>
		<label>
			<input type="checkbox" id="show-details" checked>
			Show Details
		</label>
		<br><br>
		<div class="well" id="export-list">
			<ul></ul>
			<button class="btn btn-sm btn-default hide clear">Clear</button>
		</div>
	</div>
};

print "<div class=\"collections clearfix\" style=\"margin-left: 250px;\">";

my %colors;
foreach my $color (FlavorsData::ColorList($dbh)) {
	$colors{$color->{NAME}} = $color;
}

foreach my $collection (@collections) {
	my $dateacquiredstring = $collection->{DATEACQUIRED};
	$dateacquiredstring  =~ s/ (.*)/<span style='display:none;'>$1<\/span>/;
	printf(qq{
			<div 
				data-id="%s"
				data-is-mix="%s"
				data-original-title="%s"
				data-content="<ol>%s</ol>"
				data-tag-list="%s"
				data-date-acquired="%s"
				data-name="%s"
				data-artist="%s"
				data-rating="%s"
				data-energy="%s"
				data-mood="%s"
				data-last-export="%s"
				data-export-count="%s"
				class="collection has-details clearfix"
			>
		},
		$collection->{ID},
		$collection->{ISMIX} ? 1 : 0,
		$collection->{NAME},
		FlavorsUtils::EscapeHTMLAttribute(join("", map { "<li>" . $_->{NAME} . "</li>" } @{ $tracks{$collection->{ID}} })),
		FlavorsUtils::EscapeHTMLAttribute($collection->{TAGLIST}),
		$collection->{DATEACQUIRED},
		lc($collection->{NAME}),
		lc($collection->{ARTIST}),
		$collection->{RATING},
		$collection->{ENERGY},
		$collection->{MOOD},
		$collection->{LASTEXPORT},
		$collection->{EXPORTCOUNT},
	);

	my $image = sprintf("images/collections/%s.jpg", $collection->{ID});
	if (-e $image) {
		printf(qq{<img src="%s" class="album" />}, $image);
	}
	else {
		my $color = $colors{$collection->{COLOR}};
		printf(qq{
				<div class="mix" style="%s%s">
					<br>%s
				</div>
			},
			$color ? ("background-color: #" . $color->{HEX} . ";") : "",
			$color->{WHITETEXT} ? " color: white; font-weight: bold;" : "",
			$collection->{NAME},
		);
	}
	printf(qq{
			<div class="details">
				<div class="name">%s</div>
				<div class="artist">%s</div>
				<div class="date-acquired">%s</div>
				<div class="rating">%s</div>
			</div>
		},
		$collection->{NAME},
		$collection->{ARTIST},
		$dateacquiredstring,
		FlavorsHTML::Rating($collection->{RATING}),
	);
	print "</div>";
}
print "</div>";

print FlavorsHTML::Footer();
