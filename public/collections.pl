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
<div class="post-nav">
	<div class="controls">
		<input type="text" id="collection-filter" placeholder="name">
		<input type="text" id="tag-filter" placeholder="tags">
		<br /><br />
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
			<div class="subtle">drag collections here</div>
			<ul></ul>
			<button class="btn btn-sm btn-default hide">Clear</button>
		</div>
	</div>
};

print "<div class=\"collections clearfix\" style=\"margin-left: 250px;\">";

my %colors;
foreach my $color (FlavorsData::ColorList($dbh)) {
	$colors{$color->{NAME}} = $color;
}

foreach my $collection (@collections) {
	printf(qq{
			<div 
				data-id="%s"
				data-is-mix="%s"
				data-original-title="%s"
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
		my @tags = split(/\s+/, $collection->{TAGLIST});
		@tags = @tags[0..3];
		printf(qq{
				<div class="mix" style="%s%s">
					%s
				</div>
			},
			$color ? ("background-color: #" . $color->{HEX} . ";") : "",
			$color->{WHITETEXT} ? " color: white; font-weight: bold;" : "",
			join("", map { "<div>$_</div>" } @tags),
		);
	}
	printf(qq{
			<div class="details">
				<div class="name">%s</div>
				<div class="artist">%s</div>
				<div class="date-acquired">%s</div>
				<div class="export-icons">
					<span class="glyphicon glyphicon-home" data-os="mac"></span>
					<span class="glyphicon glyphicon-briefcase" data-os="pc"></span>
				</div>
				<div class="rating">%s</div>
			</div>
		},
		$collection->{NAME},
		$collection->{ARTIST},
		FlavorsUtils::TrimDate($collection->{DATEACQUIRED}),
		FlavorsHTML::Rating($collection->{RATING}),
	);

	my $exporttext = "";
	if ($collection->{EXPORTCOUNT} == 0) {
		$exporttext = "Never exported";
	}
	else {
		$exporttext = "Exported ";
		if ($collection->{EXPORTCOUNT} == 1) {
			$exporttext .= "once, on ";
		}
		else {
			if ($collection->{EXPORTCOUNT} == 2) {
				$exporttext .= "twice";
			}
			else {
				$exporttext .= $collection->{EXPORTCOUNT} . " times";
			}
			$exporttext .= ", last on ";
		}
		$exporttext .= " " . FlavorsUtils::TrimDate($collection->{LASTEXPORT});
	}
	printf(qq{
			<div class="track-list clear">
				%s
				%s
				%s
				<ol>%s</ol>
			</div>
		},
		$exporttext,
		$collection->{ENERGY} ? "<br>Energy <div class='rating'>" . FlavorsHTML::Rating($collection->{ENERGY}) . "</div>" : "",
		$collection->{MOOD} ? "<br>Mood <div class='rating'>" . FlavorsHTML::Rating($collection->{MOOD}) . "</div>" : "",
		join("", map { "<li>" . $_->{NAME} . "</li>" } @{ $tracks{$collection->{ID}} }),
	);
	print "</div>";
}
print "</div></div>";

print FlavorsHTML::Footer();
