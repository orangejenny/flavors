#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsUtils;
use FlavorsData;
use JSON qw(to_json);

my $dbh = FlavorsData::DBH();
my $fdat = FlavorsUtils::Fdat();

my $cgi = CGI->new;
print $cgi->header();

my @songs = FlavorsData::SongList($dbh, {
	FILTER => $fdat->{FILTER},
	ORDERBY => $fdat->{ORDERBY},
});

my $tokens = {};	# token => [songid1, songid2, ... ]
foreach my $song (@songs) {
	my @songtokens = split(/\s+/, lc(join(" ", $song->{NAME}, $song->{ARTIST}, $song->{COLLECTIONS}, $song->{TAGS})));
	my $songtokenset = {};
	foreach my $token (@songtokens) {
		if ($token) {
			$songtokenset->{$token} = 1;
		}
	}
	foreach my $token (keys $songtokenset) {
		if (!$tokens->{$token}) {
			$tokens->{$token} = [];
		}
		push($tokens->{$token}, $song->{ID});
	}
}

my $letters = {};	# letter => [token1, token2, ... ]
foreach my $token (keys $tokens) {
	foreach my $letter (split(//, $token)) {
		if (!$letters->{$letter}) {
			$letters->{$letter} = [];
		}
		push($letters->{$letter}, $token);
	}
}

my $lettercounts = {};
foreach my $letter (keys $letters) {
	$lettercounts->{$letter} = scalar(@{ $letters->{$letter} });
}

FlavorsHTML::Header({
	TITLE => "Songs",
	INITIALPAGEDATA => {
		TOKENS => $tokens,
		LETTERS => $letters,
		LETTERCOUNTS => $lettercounts,
	},
});

if ($fdat->{RANDOM}) {
	my $column = $fdat->{RANDOM};
	my $item = FlavorsData::RandomItem($dbh, $column);
	$item = FlavorsUtils::EscapeSQL($item);
	if ($column =~ m/collection/i) {
		$fdat->{FILTER} = sprintf("collectionlist like '%% %s %%'", $item);
	}
	elsif ($column =~ m/tag/i) {
		$fdat->{FILTER} = sprintf("taglist like '%% %s %%'", $item);
	}
	else {
		$fdat->{FILTER} = sprintf("%s = '%s'", $column, $item);
	}
	$fdat->{PLACEHOLDER} = "";
}

print sprintf(q{
	<div id="helpers" class="modal">
		<div class="modal-dialog">
			<div class="modal-content">
				<div class="modal-header">
					<h4>Songs</h4>
				</div>

				<form method=POST id="complex-filter">
					<textarea name=filter rows=3 style="width: 400px;" placeholder="%s">%s</textarea>
					<input type="button" value="Filter" class="btn btn-default btn-lg" style="width: 400px;" />
					<input type="hidden" name="random" value="" />
					<input type="hidden" name="orderBy" value="" />
					<input type="hidden" name="placeholder" value="" />
				</form>

		id, name, artist,
		<br>rating, energy, mood,
		<br>time, filename,
		<br>ismix, mindateacquired, maxdateacquired,
		<br>taglist, tagcount, collectionlist,
		<br>minyear, maxyear, isstarred

				<div class="modal-body">
					<div class="group" data-category="random">
						<button class="btn btn-default">Random collection</button>
						<button class="btn btn-default">Random artist</button>
						<button class="btn btn-default">Random tag</button>
					</div>
					<div class="group" data-category="stars">
						<button class="btn btn-default">5 stars</button>
						<button class="btn btn-default">4 stars</button>
						<button class="btn btn-default">3 stars</button>
					</div>
					<div class="group" data-category="missing">
						<button class="btn btn-default">Missing rating</button>
						<button class="btn btn-default">Missing mood</button>
						<button class="btn btn-default">Missing energy</button>
					</div>
					<div class="group" data-category="popular">
						<button class="btn btn-default">Recently added</button>
						<button class="btn btn-default">Recently exported</button>
						<button class="btn btn-default">Frequently exported</button>
					</div>
					<div class="group" data-category="unpopular">
						<button class="btn btn-default">Rarely exported</button>
						<button class="btn btn-default btn-info">All songs</button>
						<button class="btn btn-default">Exported long ago</button>
					</div>
				</div>
			</div>
		</div>
	</div>
},
	$fdat->{PLACEHOLDER},
	$fdat->{FILTER},
);

print qq{
	<div class="post-nav">
		<div class="filter-container">
			<div id="filter-container">
				<span class='glyphicon glyphicon-search'></span>
				<input id='filter' type='text'/>
			</div>
			<a href='#'>advanced search</a>
		</div>
};

print qq{ <div id="top-veil"></div> };
print qq{ <div id="song-table-container"> };

print qq{ <table><tbody> };

my @colors = FlavorsData::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
	$colormap{$color->{NAME}} = $color->{HEX};
}
foreach my $song (@songs) {
	print sprintf(qq {
		<tr id="song-%s" data-song-id="%s" data-colors="%s">
			<td class='isstarred'><span class='glyphicon glyphicon-star%s'></span></td>
			<td>%s</td>
			<td>%s</td>
			<td>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true'>%s</td>
		</tr>
		},
		$song->{ID},
		$song->{ID},
		join(" ", map { $colormap{$_} } grep { exists $colormap{$_} } split(/\s+/, $song->{TAGS})),
		$song->{ISSTARRED} ? "" : "-empty",
		$song->{NAME},
		$song->{ARTIST},
		$song->{COLLECTIONS},
		FlavorsHTML::Rating($song->{RATING}, 'star'),
		FlavorsHTML::Rating($song->{ENERGY}, 'fire'),
		FlavorsHTML::Rating($song->{MOOD}, 'heart'),
		$song->{TAGS},
	);
}

print qq{ </tbody></table> };

print qq{</div> };
print qq{ </div> };

print qq{
	<div id="song-count-container">
		<div id="bottom-veil"></div>
		<span id="song-count-span" class="ui-corner-all">
			<span id="song-count"></span> songs
		</span>
	</div>
};

print FlavorsHTML::Footer();
