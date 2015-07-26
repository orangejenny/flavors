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
	BUTTONS => FlavorsHTML::ExportButton(),
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

print sprintf(qq{
<div class="post-nav">
	<div class="controls">
		<button id='add-collection' class='btn btn-default btn-large'>
			<span class='glyphicon glyphicon-plus'></span>
			New
		</button>
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
		<br><br>
		<div class="well" id="export-list">
			<div class="subtle">
				drag collections here to export
				<br><br>
				<a href='#' id='suggestions-trigger'>
					suggest some collections
				</a>
			</div>
			<ul></ul>
		</div>
	</div>
	},
);

print "<div class=\"collections clearfix\">";

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
				<div class="export-icons">
					<br><br>
					<span class="glyphicon glyphicon-download"></span>
				</div>
				<div class="rating">%s</div>
				<br><div class="rating">%s</div>
				<br><div class="rating">%s</div>
			</div>
		},
		$collection->{NAME},
		$collection->{ARTIST},
		FlavorsHTML::Rating($collection->{RATING}, 'star'),
		FlavorsHTML::Rating($collection->{ENERGY}, 'fire'),
		FlavorsHTML::Rating($collection->{MOOD}, 'heart'),
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
			$exporttext .= "<br>Last exported ";
		}
		$exporttext .= " " . FlavorsUtils::TrimDate($collection->{LASTEXPORT});
	}
	printf(qq{
			<div class="track-list clear">
				%s
				<div>Acquired %s</div>
				<ol>%s</ol>
			</div>
		},
		$exporttext,
		FlavorsUtils::TrimDate($collection->{DATEACQUIRED}),
		join("", map { "<li>" . $_->{NAME} . "</li>" } @{ $tracks{$collection->{ID}} }),
	);
	print "</div>";
}
print "</div></div>";

print q{
	<div id="new-collection" class="modal">
		<div class="modal-dialog modal-lg">
			<div class="modal-content">
				<button type="button" class="close" data-dismiss="modal">
					<span aria-hidden="true">&times;</span><span class="sr-only">Close</span>
				</button>
				<div class="modal-header">
					<h4>
						<input type='text' name='name' placeholder='collection' />
						<label>
							<input type='checkbox' name='ismix' />
							is mix
						</label>
					</h4>
				</div>
				<div class="modal-body">
					<div class='song hide'>
						<span class='ordinal'>0</span>
						<input type='text' name='name' placeholder='song' />
						<input type='text' name='artist' placeholder='artist' />
						<input type='text' name='minutes' placeholder='0' />
						:
						<input type='text' name='seconds' placeholder='00' />
						<span class='glyphicon glyphicon-trash'></span>
					</div>
					<div id="add-song">
						<button class='btn btn-default btn-large'>
							<span class='glyphicon glyphicon-plus'></span>
						</button>
						<input type='text' value='1' />
					</div>
				</div>
				<div class="modal-footer">
					<button id='cancel-add-collection' class='btn btn-default btn-large'>
						cancel
					</button>
					<button id='save-collection' class='btn btn-primary btn-large'>
						save
					</button>
				</div>
			</div>
		</div>
	</div>
};

print FlavorsHTML::Footer();
